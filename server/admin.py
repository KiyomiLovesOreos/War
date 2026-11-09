#!/usr/bin/env python3
# Admin tool for the War relay database.
# Run on the server: python3 /opt/admin.py <command> [args]
#
# Commands:
#   stats <username>              show account + stats summary
#   rollback <username> <id>      delete a specific game_result row by id
#   rollback_last <username> <n>  delete last N results for a user
#   reset_pw <username>           clear verifier/salt (forces re-register)
#   ban <username>                delete all sessions (forces re-login; add manual block if needed)
#   delete <username>             permanently delete account and all associated data
#   grant <username> <icon_key>   add icon entitlement
#   revoke <username> <icon_key>  remove icon entitlement
#   entitlements <username>       list all granted/earned icons
#   results <username> [gamemode] show raw game_results rows

import sys
import sqlite3

# Keep in step with ACHIEVEMENTS in relay.py — tests/test_protocol_contracts.py
# fails the suite if these drift.
ACHIEVEMENT_ICONS = {
    'jolly', 'oops', 'droll', 'meta', 'brilliant', 'blunder', 'the_soul',
    'oneshot', 'egg', 'bloodstone', 'pizza', 'riff_raff', 'garygpt',
    'missing_joker', 'cola', 'osage', 'stone', 'gold', 'steel', 'wild', 'mult',
    'lucky', 'white_stake', 'red_stake', 'green_stake', 'blue_stake',
    'black_stake', 'purple_stake', 'orange_stake', 'gold_stake', 'jimbo_stake',
    'red_deck', 'blue_deck', 'yellow_deck', 'green_deck', 'black_deck',
    'ghost_deck', 'painted_deck', 'plasma_deck', 'red_seal', 'blue_seal',
    'gold_seal', 'purple_seal',
}

DB = "/opt/war.db"
con = sqlite3.connect(DB)
con.row_factory = sqlite3.Row

def get_user(username):
    row = con.execute("SELECT * FROM users WHERE username=? COLLATE NOCASE", (username,)).fetchone()
    if not row:
        print(f"no user: {username}")
        sys.exit(1)
    return row

cmd = sys.argv[1] if len(sys.argv) > 1 else ''

if cmd == 'stats':
    u = get_user(sys.argv[2])
    print(f"id={u['id']} username={u['username']}")
    rows = con.execute(
        "SELECT gamemode, COUNT(*) played, SUM(won) wins, MAX(ante) best_ante "
        "FROM game_results WHERE user_id=? GROUP BY gamemode", (u['id'],)
    ).fetchall()
    for r in rows:
        print(f"  {r['gamemode']}: {r['wins']}/{r['played']} wins  best ante={r['best_ante']}")
    ent = con.execute("SELECT key FROM user_entitlements WHERE user_id=?", (u['id'],)).fetchall()
    if ent:
        print(f"  entitlements: {', '.join(r['key'] for r in ent)}")

elif cmd == 'rollback':
    u    = get_user(sys.argv[2])
    rid  = int(sys.argv[3])
    row  = con.execute("SELECT * FROM game_results WHERE id=? AND user_id=?", (rid, u['id'])).fetchone()
    if not row:
        print("result not found or doesn't belong to that user")
        sys.exit(1)
    print(f"deleting: id={row['id']} gamemode={row['gamemode']} won={row['won']} ante={row['ante']}")
    con.execute("DELETE FROM game_results WHERE id=?", (rid,))
    con.commit()
    print("done")

elif cmd == 'rollback_last':
    u = get_user(sys.argv[2])
    n = int(sys.argv[3])
    ids = con.execute("SELECT id FROM game_results WHERE user_id=? ORDER BY id DESC LIMIT ?", (u['id'], n)).fetchall()
    for row in ids:
        con.execute("DELETE FROM game_results WHERE id=?", (row['id'],))
    con.commit()
    print(f"deleted {len(ids)} results")

elif cmd == 'reset_pw':
    u = get_user(sys.argv[2])
    con.execute("UPDATE users SET verifier='', salt='' WHERE id=?", (u['id'],))
    con.execute("DELETE FROM sessions WHERE user_id=?", (u['id'],))
    con.commit()
    print(f"credentials cleared for {u['username']} — they must re-register")

elif cmd == 'ban':
    u = get_user(sys.argv[2])
    con.execute("DELETE FROM sessions WHERE user_id=?", (u['id'],))
    con.commit()
    print(f"all sessions killed for {u['username']}")

elif cmd == 'delete':
    u = get_user(sys.argv[2])
    con.execute("DELETE FROM user_entitlements WHERE user_id=?", (u['id'],))
    con.execute("DELETE FROM user_stats WHERE user_id=?", (u['id'],))
    con.execute("DELETE FROM game_results WHERE user_id=?", (u['id'],))
    con.execute("DELETE FROM sessions WHERE user_id=?", (u['id'],))
    con.execute("DELETE FROM users WHERE id=?", (u['id'],))
    con.commit()
    print(f"deleted {u['username']}")

elif cmd == 'grant':
    u        = get_user(sys.argv[2])
    icon_key = sys.argv[3]
    try:
        con.execute("INSERT INTO user_entitlements (user_id, key) VALUES (?,?)", (u['id'], icon_key))
        con.commit()
        print(f"granted {icon_key} to {u['username']}")
    except sqlite3.IntegrityError:
        print(f"{u['username']} already has {icon_key}")

elif cmd == 'revoke':
    u        = get_user(sys.argv[2])
    icon_key = sys.argv[3]
    n = con.execute("DELETE FROM user_entitlements WHERE user_id=? AND key=?", (u['id'], icon_key)).rowcount
    con.commit()
    if n:
        print(f"revoked {icon_key} from {u['username']}")
    else:
        print(f"{u['username']} did not have {icon_key}")

elif cmd == 'entitlements':
    u    = get_user(sys.argv[2])
    rows = con.execute("SELECT key FROM user_entitlements WHERE user_id=?", (u['id'],)).fetchall()
    if not rows:
        print("  none")
    for r in rows:
        kind = 'achievement' if r['key'] in ACHIEVEMENT_ICONS else 'grant'
        print(f"  {r['key']}  ({kind})")

elif cmd == 'results':
    u  = get_user(sys.argv[2])
    gm = sys.argv[3] if len(sys.argv) > 3 else None
    if gm:
        rows = con.execute(
            "SELECT * FROM game_results WHERE user_id=? AND gamemode=? ORDER BY id DESC LIMIT 50",
            (u['id'], gm)
        ).fetchall()
    else:
        rows = con.execute(
            "SELECT * FROM game_results WHERE user_id=? ORDER BY id DESC LIMIT 50",
            (u['id'],)
        ).fetchall()
    for r in rows:
        print(f"  id={r['id']} {r['gamemode']} won={r['won']} ante={r['ante']}")

else:
    print("commands: stats, rollback, rollback_last, reset_pw, ban, delete, grant, revoke, entitlements, results")

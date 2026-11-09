import asyncio
import json
import math
import secrets
import string
import time
import hashlib
import hmac
import os
import sqlite3
import logging
import socket as _socket

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(message)s')
log = logging.getLogger(__name__)

# Entitlements
ENTITLEMENTS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'war_entitlements.json')

# All icon keys the client can offer, grouped by how they unlock. Kept in step
# with DEV/icon_order.md by tests/test_protocol_contracts.py.
FREE_ICONS = {
    'jimbo', 'blueprint', 'brainstorm', 'verity', 'sock_and_buskin',
    'photograph', 'drool', 'stencil', 'spades', 'hearts', 'clubs', 'diamonds',
    'spades_hc', 'hearts_hc', 'clubs_hc', 'diamonds_hc',
    'ralsei', 'eight_ball', 'even_steven', 'odd_todd', 'missing',
    'azure', 'flowery', 'pig', 'persona',
    'raised_fist', 'popcorn', 'gift_card', 'stamp', 'superposition',
    'fibonacci', 'scholar', 'ride_the_bus', 'pareidolia', 'brutalists_heart',
}

SPECIAL_ICONS = {
    'bean', 'zaino', 'doc', 'murphy', 'thunderedge', 'soulware',
    'sheila', 'astra', 'lizie', 'inky', 'revo', 'argel', 'baggute',
}

def _ach(threshold=None, stat=None, reserved=False):
    """One achievement definition.

    threshold - client sends incrementAchievement and the server accumulates
                until this many; None means a one-off claim.
    stat      - (name, count) the relay awards by itself from game_results;
                names live in STAT_QUERIES.
    reserved  - defined but not handed out yet (no client tracking or sheet
                row), so claims for it are ignored. Admin grants still work.
    """
    return {'threshold': threshold, 'stat': stat, 'reserved': reserved}

# Key -> definition. The icon a key unlocks is the key itself; add 'icon' here
# if an achievement ever needs to hand out a different one.
ACHIEVEMENTS = {
    'jolly':         _ach(),
    'oops':          _ach(),
    'droll':         _ach(),
    'meta':          _ach(stat=('matches', 100)),
    'brilliant':     _ach(stat=('wins', 10)),
    'blunder':       _ach(stat=('losses', 10)),
    'the_soul':      _ach(),
    'oneshot':       _ach(threshold=100),
    'egg':           _ach(),
    'bloodstone':    _ach(threshold=100),
    'pizza':         _ach(threshold=100),
    'riff_raff':     _ach(),
    'garygpt':       _ach(),
    'missing_joker': _ach(),
    'cola':          _ach(),
    'osage':         _ach(threshold=1000),
    'stone':         _ach(threshold=100),
    'gold':          _ach(threshold=100),
    'steel':         _ach(threshold=100),
    'wild':          _ach(threshold=100),
    'mult':          _ach(threshold=100),
    'lucky':         _ach(threshold=100),
    'white_stake':   _ach(threshold=10),
    'red_stake':     _ach(threshold=10),
    'green_stake':   _ach(threshold=10),
    'blue_stake':    _ach(threshold=10),
    'black_stake':   _ach(threshold=10),
    'purple_stake':  _ach(threshold=10),
    'orange_stake':  _ach(threshold=10),
    'gold_stake':    _ach(threshold=10),
    'jimbo_stake':   _ach(),             # auto-granted when all 8 vanilla stakes earned
    'red_deck':      _ach(threshold=10),
    'blue_deck':     _ach(threshold=10),
    'yellow_deck':   _ach(threshold=10),
    'green_deck':    _ach(threshold=10),
    'black_deck':    _ach(threshold=10),
    'ghost_deck':    _ach(threshold=10),
    'painted_deck':  _ach(threshold=10),
    'plasma_deck':   _ach(threshold=10),
    'red_seal':      _ach(threshold=100),
    'blue_seal':     _ach(threshold=100),
    'gold_seal':     _ach(threshold=100),
    'purple_seal':   _ach(threshold=100),
}

# Stake keys that must all be earned to auto-grant jimbo_stake.
VANILLA_STAKE_KEYS = frozenset({
    'white_stake', 'red_stake', 'green_stake', 'blue_stake',
    'black_stake', 'purple_stake', 'orange_stake', 'gold_stake',
})

# Derived views, so handlers never carry a second copy of these lists.
ACHIEVEMENT_ICONS      = {k: v.get('icon') or k for k, v in ACHIEVEMENTS.items()}
ACHIEVEMENT_THRESHOLDS = {k: v['threshold'] for k, v in ACHIEVEMENTS.items() if v['threshold']}
KNOWN_ICONS            = FREE_ICONS | SPECIAL_ICONS | set(ACHIEVEMENT_ICONS)

STAT_QUERIES = {
    'matches': "SELECT COUNT(*) FROM game_results WHERE user_id=?",
    'wins':    "SELECT COUNT(*) FROM game_results WHERE user_id=? AND won=1",
    'losses':  "SELECT COUNT(*) FROM game_results WHERE user_id=? AND won=0",
}

def get_user_entitlements(username):
    if not username:
        return []
    row = db.execute("SELECT id FROM users WHERE username=? COLLATE NOCASE", (username,)).fetchone()
    if not row:
        return []
    rows = db.execute("SELECT key FROM user_entitlements WHERE user_id=?", (row['id'],)).fetchall()
    return [r['key'] for r in rows]

def validate_icon(username, icon_key):
    if not icon_key or icon_key == 'default':
        return icon_key or 'default'
    if icon_key not in KNOWN_ICONS:
        return 'default'
    if icon_key in FREE_ICONS:
        return icon_key
    return icon_key if icon_key in get_user_entitlements(username) else 'default'

def grant_achievement(username, ach_key):
    if not username:
        return False
    icon_key = ACHIEVEMENT_ICONS.get(ach_key)
    if not icon_key:
        return False
    row = db.execute("SELECT id FROM users WHERE username=? COLLATE NOCASE", (username,)).fetchone()
    if not row:
        return False
    existing = db.execute("SELECT 1 FROM user_entitlements WHERE user_id=? AND key=?", (row['id'], icon_key)).fetchone()
    if existing:
        return False
    db.execute("INSERT INTO user_entitlements (user_id, key) VALUES (?,?)", (row['id'], icon_key))
    db.commit()
    log.info(f"achievement {ach_key} granted")
    return True

def increment_achievement_counter(uid, key, amount):
    """Add amount to the counter; return True if the threshold is now met."""
    threshold = ACHIEVEMENT_THRESHOLDS.get(key)
    if not threshold or amount <= 0:
        return False
    db.execute(
        "INSERT INTO achievement_counters (user_id, key, count) VALUES (?,?,?) "
        "ON CONFLICT(user_id, key) DO UPDATE SET count = count + excluded.count",
        (uid, key, amount)
    )
    db.commit()
    row = db.execute(
        "SELECT count FROM achievement_counters WHERE user_id=? AND key=?",
        (uid, key)
    ).fetchone()
    return bool(row and row['count'] >= threshold)

STATUS_FILE = '/tmp/war_relay_status.json'

def _write_status():
    names = sorted(set(
        info['username'] for info in clients.values() if info.get('username')
    ))
    try:
        with open(STATUS_FILE, 'w') as f:
            json.dump({'total': len(clients), 'users': names}, f)
    except Exception:
        pass

HOST          = "0.0.0.0"
PORT          = 7777
CODE_LEN      = 5
CODE_CHARS    = string.ascii_uppercase + string.digits
CODE_TTL      = 300
MSG_MAX       = 65536
TOKEN_TTL     = 60 * 60 * 24 * 30  # 30 days
SESSION_CAP   = 1
PING_INTERVAL = 15    # seconds between heartbeat pings sent to each client
PONG_TIMEOUT  = 10    # seconds to wait for pong before treating connection as dead
HOST_TTL      = 60    # seconds to hold a lobby after the host drops (reconnect window)

DB_PATH = "/opt/war.db"

# database

def db_connect():
    con = sqlite3.connect(DB_PATH, check_same_thread=False)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA foreign_keys=ON")
    return con

def db_init(con):
    con.executescript("""
        CREATE TABLE IF NOT EXISTS users (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            username    TEXT    UNIQUE NOT NULL COLLATE NOCASE,
            salt        TEXT    NOT NULL,
            verifier    TEXT    NOT NULL,
            avatar_data TEXT    DEFAULT NULL
        );

        CREATE TABLE IF NOT EXISTS sessions (
            token       TEXT    PRIMARY KEY,
            user_id     INTEGER NOT NULL REFERENCES users(id),
            expires_at  INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS game_results (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     INTEGER NOT NULL REFERENCES users(id),
            gamemode    TEXT    NOT NULL,
            won         INTEGER NOT NULL,
            ante        INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS user_entitlements (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id),
            key     TEXT    NOT NULL,
            UNIQUE(user_id, key)
        );
    """)
    con.commit()

def db_migrate(con):
    cols = {r[1] for r in con.execute("PRAGMA table_info(users)")}
    if 'last_login' in cols:
        con.execute("ALTER TABLE users DROP COLUMN last_login")
        con.commit()
    if 'created_at' in cols:
        con.execute("ALTER TABLE users DROP COLUMN created_at")
        con.commit()
    if 'avatar_data' not in cols:
        con.execute("ALTER TABLE users ADD COLUMN avatar_data TEXT DEFAULT NULL")
        con.commit()
    cols = {r[1] for r in con.execute("PRAGMA table_info(sessions)")}
    if 'created_at' in cols:
        con.execute("ALTER TABLE sessions DROP COLUMN created_at")
        con.commit()
    # remove old score column if it exists
    cols = {r[1] for r in con.execute("PRAGMA table_info(game_results)")}
    if 'played_at' in cols:
        con.execute("ALTER TABLE game_results DROP COLUMN played_at")
        con.commit()
    if 'score' in cols:
        con.execute("ALTER TABLE game_results DROP COLUMN score")
        con.commit()
    if not con.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='user_stats'").fetchone():
        con.execute("""CREATE TABLE user_stats (
            user_id    INTEGER NOT NULL REFERENCES users(id),
            gamemode   TEXT    NOT NULL,
            best_score REAL    NOT NULL DEFAULT 0,
            PRIMARY KEY (user_id, gamemode)
        )""")
        con.commit()
    if not con.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='user_entitlements'").fetchone():
        con.execute("""CREATE TABLE user_entitlements (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL REFERENCES users(id),
            key     TEXT    NOT NULL,
            UNIQUE(user_id, key)
        )""")
        con.commit()
    con.execute("DROP TABLE IF EXISTS audit_log")
    con.commit()
    if not con.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='achievement_counters'").fetchone():
        con.execute("""CREATE TABLE achievement_counters (
            user_id  INTEGER NOT NULL REFERENCES users(id),
            key      TEXT    NOT NULL,
            count    INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (user_id, key)
        )""")
        con.commit()
    # Migrate war_entitlements.json → user_entitlements table (runs once).
    if os.path.exists(ENTITLEMENTS_FILE):
        try:
            with open(ENTITLEMENTS_FILE) as f:
                data = json.load(f)
            for uname, keys in data.get('account_locks', {}).items():
                row = con.execute("SELECT id FROM users WHERE username=? COLLATE NOCASE", (uname,)).fetchone()
                if row:
                    for k in keys:
                        con.execute("INSERT OR IGNORE INTO user_entitlements (user_id, key) VALUES (?,?)", (row['id'], k))
            for uname, achs in data.get('achievements', {}).items():
                row = con.execute("SELECT id FROM users WHERE username=? COLLATE NOCASE", (uname,)).fetchone()
                if row:
                    for ach_key, earned in achs.items():
                        if earned:
                            icon_key = ACHIEVEMENT_ICONS.get(ach_key, ach_key)
                            con.execute("INSERT OR IGNORE INTO user_entitlements (user_id, key) VALUES (?,?)", (row['id'], icon_key))
            con.commit()
            os.rename(ENTITLEMENTS_FILE, ENTITLEMENTS_FILE + '.migrated')
            log.info("entitlements migrated from JSON to DB")
        except Exception as e:
            log.warning(f"entitlements migration failed: {e}")

db = db_connect()
db_init(db)
db_migrate(db)

# helpers

def now():
    return int(time.time())

def sha256(s):
    return hashlib.sha256(s.encode()).hexdigest()

def make_token():
    return hashlib.sha256(os.urandom(32)).hexdigest()

def verify_password(verifier, candidate_verifier):
    return hmac.compare_digest(verifier, candidate_verifier)

def gen_code():
    while True:
        code = ''.join(secrets.choice(CODE_CHARS) for _ in range(CODE_LEN))
        if code not in lobbies:
            return code

def gen_seed():
    return ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(8))

def parse_score(s):
    try:
        return float(str(s))
    except (TypeError, ValueError):
        return 0.0

def cleanup_stale():
    t = now()
    dead = [c for c, l in lobbies.items() if (
        # Empty lobbies past TTL (host present and connected, no guest)
        (t - l['created'] > CODE_TTL and not l['guest']
            and l['host'] and l['host'] not in clients
            and not l.get('_host_reconnect_deadline')) or
        # Guest reconnect window expired
        (l.get('_reconnect_deadline') and t > l['_reconnect_deadline']) or
        # Host reconnect window expired
        (l.get('_host_reconnect_deadline') and t > l['_host_reconnect_deadline']) or
        # Both slots empty with no pending reconnect window
        (not l['host'] and not l['guest']
            and not l.get('_reconnect_deadline')
            and not l.get('_host_reconnect_deadline')) or
        # Host socket gone without a reconnect window (orphan guard)
        (l['host'] is not None and l['host'] not in clients
            and not l.get('_host_reconnect_deadline'))
    )]
    for c in dead:
        del lobbies[c]

def new_game_state():
    return {
        'is_in_game':              False,
        'seed':                    None,
        # per-player
        'host_lives':              4,
        'guest_lives':             4,
        'host_score':              0.0,
        'guest_score':             0.0,
        'host_hands_left':         4,
        'guest_hands_left':        4,
        'host_ready_blind':        False,
        'guest_ready_blind':       False,
        'host_first_ready':        False,
        'guest_first_ready':       False,
        'host_played_this_blind':  False,
        'guest_played_this_blind': False,
        'host_round_lives_blocker':False,
        'guest_round_lives_blocker':False,
        'host_timer_lives_blocker': False,
        'guest_timer_lives_blocker':False,
        '_blind_timer_task':        None,
        '_timer_start':             None,
        '_timer_secs':              0,
        '_timer_late_role':         None,
        '_timer_paused':            False,
        '_timer_paused_remaining':  None,
        'host_ante':               1,
        'guest_ante':              1,
        'host_skips':              0,
        'guest_skips':             0,
        '_in_pvp_blind':           False,
        '_first_ready_at':         None,
        '_host_best':              0.0,
        '_guest_best':             0.0,
    }

# state

lobbies = {}   # code -> lobby dict
clients = {}   # writer -> {code, role, user_id, username}
_guest_counter = 0

# network helpers

async def send(writer, msg):
    try:
        info = clients.get(writer)
        if info is not None:
            seq = info.get('_seq', 0)
            msg = {**msg, '_seq': seq}
            info['_seq'] = seq + 1
        writer.write((json.dumps(msg) + '\n').encode())
        await writer.drain()
    except Exception:
        pass

async def broadcast(lobby, msg, exclude=None):
    for role in ('host', 'guest'):
        w = lobby.get(role)
        if w and w != exclude:
            await send(w, msg)

def get_enemy_writer(lobby, role):
    return lobby['guest'] if role == 'host' else lobby['host']

def get_enemy_role(role):
    return 'guest' if role == 'host' else 'host'

# auth handlers

async def handle_register(writer, msg):
    username = (msg.get('username') or '').strip()
    salt     = msg.get('salt')
    verifier = msg.get('verifier')

    if not username or not salt or not verifier:
        await send(writer, {'action': 'auth_error', 'reason': 'missing_fields'})
        return
    if len(username) < 2 or len(username) > 24:
        await send(writer, {'action': 'auth_error', 'reason': 'bad_username'})
        return

    try:
        db.execute(
            "INSERT INTO users (username, salt, verifier) VALUES (?,?,?)",
            (username, salt, verifier)
        )
        db.commit()
        await send(writer, {'action': 'registered', 'username': username})
    except sqlite3.IntegrityError:
        await send(writer, {'action': 'auth_error', 'reason': 'username_taken'})

async def handle_get_salt(writer, msg):
    username = (msg.get('username') or '').strip()
    row = db.execute("SELECT salt FROM users WHERE username=?", (username,)).fetchone()
    if not row:
        fake = sha256(username + "war_fake_salt")[:32]
        await send(writer, {'action': 'salt', 'salt': fake})
        return
    await send(writer, {'action': 'salt', 'salt': row['salt']})

async def handle_login(writer, msg):
    username = (msg.get('username') or '').strip()
    verifier = msg.get('verifier')

    row = db.execute("SELECT id, verifier FROM users WHERE username=?", (username,)).fetchone()
    if not row or not verify_password(row['verifier'], verifier):
        await send(writer, {'action': 'auth_error', 'reason': 'bad_credentials'})
        return

    existing = db.execute(
        "SELECT token FROM sessions WHERE user_id=? ORDER BY expires_at ASC",
        (row['id'],)
    ).fetchall()
    if len(existing) >= SESSION_CAP:
        for old in existing[:len(existing) - SESSION_CAP + 1]:
            db.execute("DELETE FROM sessions WHERE token=?", (old['token'],))

    token   = make_token()
    expires = now() + TOKEN_TTL
    db.execute(
        "INSERT INTO sessions (token, user_id, expires_at) VALUES (?,?,?)",
        (token, row['id'], expires)
    )
    db.commit()
    clients[writer]['user_id']  = row['id']
    clients[writer]['username'] = username
    # Fetch avatar to include in response
    av_row = db.execute("SELECT avatar_data FROM users WHERE id=?", (row['id'],)).fetchone()
    avatar = av_row['avatar_data'] if av_row and av_row['avatar_data'] else "default"
    entitlements = get_user_entitlements(username)
    clients[writer]['_sent_entitlements'] = set(entitlements)
    await send(writer, {'action': 'logged_in', 'token': token, 'username': username,
                        'avatar': avatar, 'entitlements': entitlements})

async def handle_token_login(writer, msg):
    token = msg.get('token')
    row = db.execute(
        "SELECT s.user_id, u.username, u.avatar_data, s.expires_at FROM sessions s "
        "JOIN users u ON u.id=s.user_id WHERE s.token=?",
        (token,)
    ).fetchone()
    if not row or row['expires_at'] < now():
        await send(writer, {'action': 'auth_error', 'reason': 'invalid_token'})
        return
    db.execute("UPDATE sessions SET expires_at=? WHERE token=?", (now() + TOKEN_TTL, token))
    db.commit()
    clients[writer]['user_id']  = row['user_id']
    clients[writer]['username'] = row['username']
    avatar = row['avatar_data'] if row['avatar_data'] else "default"
    entitlements = get_user_entitlements(row['username'])
    clients[writer]['_sent_entitlements'] = set(entitlements)
    await send(writer, {'action': 'logged_in', 'username': row['username'],
                        'avatar': avatar, 'entitlements': entitlements})

async def handle_logout(writer, msg):
    token = msg.get('token')
    if token:
        db.execute("DELETE FROM sessions WHERE token=?", (token,))
        db.commit()
    await send(writer, {'action': 'logged_out'})

async def handle_stats(writer, msg):
    username = (msg.get('username') or '').strip()
    gamemode = msg.get('gamemode')

    row = db.execute("SELECT id FROM users WHERE username=?", (username,)).fetchone()
    if not row:
        await send(writer, {'action': 'error', 'reason': 'no_user'})
        return

    uid = row['id']
    if gamemode:
        stats = db.execute("""
            SELECT COUNT(*) as played, SUM(won) as wins, MAX(ante) as best_ante
            FROM game_results WHERE user_id=? AND gamemode=?
        """, (uid, gamemode)).fetchone()
    else:
        stats = db.execute("""
            SELECT COUNT(*) as played, SUM(won) as wins, MAX(ante) as best_ante
            FROM game_results WHERE user_id=?
        """, (uid,)).fetchone()

    await send(writer, {
        'action':   'stats',
        'username': username,
        'gamemode': gamemode,
        'played':   stats['played']   or 0,
        'wins':     stats['wins']     or 0,
        'best_ante':stats['best_ante'] or 0,
    })

async def award_stat_achievements(writer, uid, uname):
    """Grant any live stat achievement whose count has come up, and tell the
    player. One loop over ACHIEVEMENTS, so 'win N games' style keys are data."""
    for key, defn in ACHIEVEMENTS.items():
        stat = defn['stat']
        if not stat or defn['reserved']:
            continue
        name, target = stat
        query = STAT_QUERIES.get(name)
        if not query:
            log.warning(f"achievement {key}: unknown stat {name}")
            continue
        count = db.execute(query, (uid,)).fetchone()[0]
        if count >= target and grant_achievement(uname, key):
            await send(writer, {'action': 'achievementUnlocked', 'key': ACHIEVEMENT_ICONS[key]})

async def handle_record_result(lobby, winner_role):
    gm      = lobby.get('gamemode', 'vanilla')
    results = {}
    for role in ('host', 'guest'):
        uid = lobby.get(f'{role}_user_id')
        won  = 1 if role == winner_role else 0
        ante = lobby.get(f'{role}_ante', 1)
        if uid:
            db.execute(
                "INSERT INTO game_results (user_id, gamemode, won, ante) VALUES (?,?,?,?)",
                (uid, gm, won, ante)
            )
            match_best = lobby.get(f'_{role}_best', 0.0)
            prev_row = db.execute(
                "SELECT best_score FROM user_stats WHERE user_id=? AND gamemode=?",
                (uid, gm)
            ).fetchone()
            prev_best  = prev_row['best_score'] if prev_row else 0.0
            new_record = match_best > prev_best
            if new_record:
                db.execute(
                    "INSERT INTO user_stats (user_id, gamemode, best_score) VALUES (?,?,?) "
                    "ON CONFLICT(user_id, gamemode) DO UPDATE SET best_score=excluded.best_score",
                    (uid, gm, match_best)
                )
            results[role] = {
                'score':      match_best,
                'prev_best':  prev_best,
                'new_record': new_record,
                'tied':       (match_best > 0) and (match_best == prev_best),
            }
        else:
            results[role] = None
    db.commit()
    # Relay-awarded achievements (wins/losses/matches). New ones need a row in
    # ACHIEVEMENTS with a stat, nothing else.
    for role in ('host', 'guest'):
        uid = lobby.get(f'{role}_user_id')
        w   = lobby.get(role)
        if not uid or not w:
            continue
        urow  = db.execute("SELECT username FROM users WHERE id=?", (uid,)).fetchone()
        uname = urow['username'] if urow else None
        if uname:
            await award_stat_achievements(w, uid, uname)
    log.info(f"match over lobby={lobby.get('_code','?')} winner={winner_role}")
    return results

# lobby management

async def handle_create(writer, msg):
    cleanup_stale()
    code = gen_code()
    info = clients.get(writer, {})
    lobby = {
        'host':          writer,
        'guest':         None,
        'host_user_id':  info.get('user_id'),
        'guest_user_id': None,
        'created':       now(),
        'gamemode':      msg.get('gamemode', 'vanilla'),
        'options':       {'death_on_round_loss': True},   # lives, seed, back, stake, challenge, toggles
        '_code':         code,
        'host_lobby_ready':  False,
        'guest_lobby_ready': False,
        'host_pfp':          validate_icon(info.get('username'), msg.get('pfp', 'default')),
        **new_game_state(),
    }
    lobbies[code] = lobby
    clients[writer] = {**info, 'code': code, 'role': 'host',
                       'mod_version':   msg.get('mod_version'),
                       'smods_version': msg.get('smods_version')}
    await send(writer, {'action': 'created', 'code': code})
    log.info(f"lobby {code} created")

async def handle_join(writer, msg):
    code  = (msg.get('code') or '').upper().strip()
    lobby = lobbies.get(code)
    if not lobby:
        await send(writer, {'action': 'error', 'reason': 'no_lobby'})
        return
    if lobby['guest']:
        await send(writer, {'action': 'error', 'reason': 'full'})
        return
    info = clients.get(writer, {})

    if not info.get('username'):
        global _guest_counter
        _guest_counter += 1
        guest_username = f"GUEST{_guest_counter:03d}"
        clients[writer]['username'] = guest_username
    else:
        guest_username = info['username']

    host_info     = clients.get(lobby['host'], {})
    host_username = host_info.get('username', 'Host')
    guest_pfp = validate_icon(info.get('username'), msg.get('pfp', 'default'))

    lobby['guest']         = writer
    lobby['guest_user_id'] = info.get('user_id')
    # Reset readiness for both when a new guest joins
    lobby['host_lobby_ready']  = False
    lobby['guest_lobby_ready'] = False
    clients[writer] = {**clients[writer], 'code': code, 'role': 'guest',
                       'mod_version':   msg.get('mod_version'),
                       'smods_version': msg.get('smods_version')}

    await send(writer, {
        'action': 'joined', 'code': code,
        'host_username': host_username,
        'pfp': lobby.get('host_pfp', 'default'),
        'mod_version':   host_info.get('mod_version'),
        'smods_version': host_info.get('smods_version'),
    })
    await send(lobby['host'], {
        'action': 'guest_joined',
        'username': guest_username,
        'pfp': guest_pfp,
        'mod_version':   msg.get('mod_version'),
        'smods_version': msg.get('smods_version'),
    })
    # Push current lobby options to the new guest so they have pvp_start_ante,
    # timer_seconds, etc. from the moment they join (not just future changes).
    if lobby['options']:
        await send(writer, {'action': 'lobbyOptions', **lobby['options']})
    log.info(f"lobby {code} guest joined")

# game state helpers

async def lose_life(lobby, role, cause='round'):
    blocker_key = f'{role}_round_lives_blocker' if cause == 'round' else f'{role}_timer_lives_blocker'
    if lobby.get(blocker_key):
        return
    lobby[f'{role}_lives'] -= 1
    lobby[blocker_key] = True
    lives = lobby[f'{role}_lives']

    # Send playerInfo to the player who lost a life
    w = lobby[role]
    if w:
        await send(w, {'action': 'playerInfo', 'lives': lives})

    # Send enemyInfo update to the opponent
    enemy_role = get_enemy_role(role)
    enemy_w = lobby.get(enemy_role)
    if enemy_w:
        await send(enemy_w, {
            'action':    'enemyInfo',
            'handsLeft': lobby[f'{role}_hands_left'],
            'score':     str(lobby[f'{role}_score']),
            'skips':     lobby[f'{role}_skips'],
            'lives':     lives,
        })

async def reset_per_blind(lobby):
    task = lobby.pop('_blind_timer_task', None)
    if task and not task.done():
        task.cancel()
    lobby['host_ready_blind']        = False
    lobby['guest_ready_blind']       = False
    lobby['host_first_ready']        = False
    lobby['guest_first_ready']       = False
    lobby['host_played_this_blind']  = False
    lobby['guest_played_this_blind'] = False
    lobby['host_round_lives_blocker']  = False
    lobby['guest_round_lives_blocker'] = False
    lobby['host_timer_lives_blocker']  = False
    lobby['guest_timer_lives_blocker'] = False
    lobby['host_score']              = 0.0
    lobby['guest_score']             = 0.0
    lobby['host_hands_left']         = 4
    lobby['guest_hands_left']        = 4
    lobby['_in_pvp_blind']           = False
    lobby['_first_ready_at']         = None

# game action handlers

async def handle_start_game(lobby, role, msg):
    if role != 'host':
        return
    if not lobby['guest']:
        return

    opts  = lobby['options']
    lives = int(opts.get('lives', 4))
    seed  = opts.get('seed') or gen_seed()
    back      = opts.get('back')
    stake     = opts.get('stake', 1)
    challenge = opts.get('challenge', '')

    lobby['seed'] = seed
    lobby['is_in_game'] = True

    # Reset all game state
    state = new_game_state()
    state['host_lives']  = lives
    state['guest_lives'] = lives
    state['is_in_game']  = True
    state['seed']        = seed
    for k, v in state.items():
        lobby[k] = v

    await broadcast(lobby, {
        'action':    'startGame',
        'seed':      seed,
        'lives':     lives,
        'back':      back,
        'stake':     stake,
        'challenge': challenge,
    })
    log.info(f"lobby {lobby['_code']} startGame seed={seed} lives={lives}")

async def _fire_start_blind(lobby):
    first = None
    if lobby.get('host_first_ready'):    first = 'host'
    elif lobby.get('guest_first_ready'): first = 'guest'

    lobby['_in_pvp_blind'] = True
    for k, v in {
        'host_score': 0.0, 'guest_score': 0.0,
        'host_hands_left': 4, 'guest_hands_left': 4,
        'host_played_this_blind': False, 'guest_played_this_blind': False,
        'host_round_lives_blocker': False, 'guest_round_lives_blocker': False,
    }.items():
        lobby[k] = v

    out = {'action': 'startBlind'}
    if first:
        out['firstPlayer'] = first
    await broadcast(lobby, out)
    log.info(f"lobby {lobby['_code']} startBlind first={first}")

async def _broadcast_blind_timer(lobby, secs, late_role=None, paused=False):
    # The clock lives on the relay: both clients display the same deadline and
    # only the late player is on it. seconds=0 means "no timer running".
    msg = {'action': 'blindTimer', 'seconds': secs, 'late': late_role}
    if paused:
        msg['paused'] = True
    await broadcast(lobby, msg)

async def _blind_timer_coro(lobby, late_role, secs):
    try:
        await asyncio.sleep(secs)
        if lobby.get(f'{late_role}_ready_blind'):
            return  # second player readied just in time
        await lose_life(lobby, late_role, cause='timer')
        log.info(f"lobby {lobby['_code']} blind timer: {late_role} lost a life ({lobby.get(f'{late_role}_lives', 0)} remaining)")
        # If that life was the last one, end the game now
        if lobby.get(f'{late_role}_lives', 1) <= 0:
            winner_role   = get_enemy_role(late_role)
            score_results = await handle_record_result(lobby, winner_role)
            winner_msg, loser_msg = _make_gameover_msgs(lobby, winner_role, score_results)
            winner_w = lobby.get(winner_role)
            loser_w  = lobby.get(late_role)
            if winner_w: await send(winner_w, winner_msg)
            if loser_w:  await send(loser_w,  loser_msg)
    except asyncio.CancelledError:
        pass
    finally:
        lobby.pop('_blind_timer_task', None)
        lobby['_timer_paused'] = False
        lobby['_timer_paused_remaining'] = None
        await _broadcast_blind_timer(lobby, 0)

async def handle_pause_timer(lobby, role, msg):
    late_role = lobby.get('_timer_late_role')
    if role == late_role: return          # only the waiting (non-late) player can pause
    if lobby.get('_timer_paused'): return  # already paused
    task = lobby.get('_blind_timer_task')
    if not task or task.done(): return
    elapsed   = time.time() - (lobby.get('_timer_start') or time.time())
    remaining = max(0.0, (lobby.get('_timer_secs') or 0) - elapsed)
    task.cancel()
    lobby.pop('_blind_timer_task', None)
    lobby['_timer_paused']           = True
    lobby['_timer_paused_remaining'] = remaining
    await _broadcast_blind_timer(lobby, math.ceil(remaining), late_role, paused=True)

async def handle_resume_timer(lobby, role, msg):
    late_role = lobby.get('_timer_late_role')
    if role == late_role: return          # only the waiting (non-late) player can resume
    if not lobby.get('_timer_paused'): return
    remaining = lobby.get('_timer_paused_remaining') or 0
    lobby['_timer_paused']           = False
    lobby['_timer_paused_remaining'] = None
    if remaining <= 0:
        await lose_life(lobby, late_role, cause='timer')
        await _broadcast_blind_timer(lobby, 0)
        return
    lobby['_blind_timer_task'] = asyncio.create_task(
        _blind_timer_coro(lobby, late_role, remaining)
    )
    lobby['_timer_start'] = time.time()
    lobby['_timer_secs']  = remaining
    await _broadcast_blind_timer(lobby, math.ceil(remaining), late_role)

async def handle_ready_blind(lobby, role, msg):
    lobby[f'{role}_ready_blind'] = True

    # Speedrun: first player to ready
    if not lobby['host_first_ready'] and not lobby['guest_first_ready']:
        lobby[f'{role}_first_ready'] = True
        lobby['_first_ready_at'] = time.time()

    if lobby['host_ready_blind'] and lobby['guest_ready_blind']:
        # Both ready: cancel any pending timer and start the blind
        task = lobby.pop('_blind_timer_task', None)
        if task and not task.done():
            task.cancel()
        await _broadcast_blind_timer(lobby, 0)
        await _fire_start_blind(lobby)
    else:
        # One player ready: start timer if configured
        enemy_role = get_enemy_role(role)
        timer_secs = int(lobby['options'].get('timer_seconds', 0) or 0)
        if timer_secs > 0:
            old = lobby.pop('_blind_timer_task', None)
            if old and not old.done():
                old.cancel()
            lobby['_blind_timer_task'] = asyncio.create_task(
                _blind_timer_coro(lobby, enemy_role, timer_secs)
            )
            lobby['_timer_start']     = time.time()
            lobby['_timer_secs']      = timer_secs
            lobby['_timer_late_role'] = enemy_role
            lobby['_timer_paused']    = False
            await _broadcast_blind_timer(lobby, timer_secs, enemy_role)

async def handle_unready_blind(lobby, role, msg):
    lobby[f'{role}_ready_blind'] = False
    task = lobby.pop('_blind_timer_task', None)
    if task and not task.done():
        task.cancel()
    await _broadcast_blind_timer(lobby, 0)

async def handle_play_hand(lobby, role, msg):
    score_str  = str(msg.get('score', '0'))
    hands_left = int(msg.get('handsLeft', 0))
    try:
        lobby[f'{role}_skips'] = int(msg.get('skips', 0) or 0)
    except (TypeError, ValueError):
        pass

    score = parse_score(score_str)
    lobby[f'{role}_score'] = score
    if score > lobby[f'_{role}_best']:
        lobby[f'_{role}_best'] = score
    lobby[f'{role}_hands_left'] = hands_left

    played_real = score > 0
    if played_real:
        lobby[f'{role}_played_this_blind'] = True

    enemy_role = get_enemy_role(role)
    hide_score = lobby['options'].get('hide_score_until_played', False)

    # Send enemyInfo to the opponent
    enemy_w = lobby.get(enemy_role)
    if enemy_w:
        show = (not hide_score) or lobby[f'{enemy_role}_played_this_blind']
        await send(enemy_w, {
            'action':    'enemyInfo',
            'handsLeft': hands_left,
            'score':     score_str if show else None,
            'noScore':   not show,
            'skips':     lobby[f'{role}_skips'],
            'lives':     lobby[f'{role}_lives'],
        })

    # Send back current enemy state to the player who just played
    my_w = lobby.get(role)
    if my_w:
        show_enemy = (not hide_score) or played_real
        await send(my_w, {
            'action':    'enemyInfo',
            'handsLeft': lobby[f'{enemy_role}_hands_left'],
            'score':     str(lobby[f'{enemy_role}_score']) if show_enemy else None,
            'noScore':   not show_enemy,
            'skips':     lobby[f'{enemy_role}_skips'],
            'lives':     lobby[f'{enemy_role}_lives'],
        })

    # Only check endPvP when in a PvP blind
    if not lobby['_in_pvp_blind']:
        return

    h = lobby['host_hands_left']
    g = lobby['guest_hands_left']
    hs = lobby['host_score']
    gs = lobby['guest_score']

    ends = (
        (g < 1 and gs < hs) or
        (h < 1 and hs < gs) or
        (h < 1 and g < 1)
    )
    if ends:
        await resolve_pvp(lobby)

def _make_gameover_msgs(lobby, winner_role, score_results):
    loser_role  = get_enemy_role(winner_role)
    winner_w    = lobby.get(winner_role)
    loser_w     = lobby.get(loser_role)
    winner_name = clients.get(winner_w, {}).get('username', '?') if winner_w else '?'
    loser_name  = clients.get(loser_w,  {}).get('username', '?') if loser_w  else '?'
    wr = score_results.get(winner_role) or {}
    lr = score_results.get(loser_role)  or {}
    winner_msg = {
        'action':     'winGame',
        **wr,
        'opp_score':      lr.get('score', 0),
        'opp_new_record': lr.get('new_record', False),
        'opp_name':       loser_name,
        'opp_ante':       lobby.get(f'{loser_role}_ante', 1),
        'opp_lives':      lobby.get(f'{loser_role}_lives', 0),
        'my_ante':        lobby.get(f'{winner_role}_ante', 1),
        'my_lives':       lobby.get(f'{winner_role}_lives', 0),
    }
    loser_msg = {
        'action':     'loseGame',
        **lr,
        'opp_score':      wr.get('score', 0),
        'opp_new_record': wr.get('new_record', False),
        'opp_name':       winner_name,
        'opp_ante':       lobby.get(f'{winner_role}_ante', 1),
        'opp_lives':      lobby.get(f'{winner_role}_lives', 0),
        'my_ante':        lobby.get(f'{loser_role}_ante', 1),
        'my_lives':       lobby.get(f'{loser_role}_lives', 0),
    }
    return winner_msg, loser_msg

async def resolve_pvp(lobby):
    lobby['_in_pvp_blind'] = False
    hs = lobby['host_score']
    gs = lobby['guest_score']
    host_w  = lobby['host']
    guest_w = lobby['guest']

    if hs == gs:
        # Draw — no life lost
        await reset_per_blind(lobby)
        await broadcast(lobby, {'action': 'endPvP', 'lost': False})
        return

    winner_role = 'host' if hs > gs else 'guest'
    loser_role  = get_enemy_role(winner_role)

    await lose_life(lobby, loser_role, 'round')

    if lobby[f'{loser_role}_lives'] <= 0:
        score_results = await handle_record_result(lobby, winner_role)
        winner_msg, loser_msg = _make_gameover_msgs(lobby, winner_role, score_results)
        winner_w = lobby[winner_role]
        loser_w  = lobby[loser_role]
        if winner_w: await send(winner_w, winner_msg)
        if loser_w:  await send(loser_w,  loser_msg)
        return

    lobby['host_first_ready']  = False
    lobby['guest_first_ready'] = False
    await reset_per_blind(lobby)

    if host_w:
        await send(host_w,  {'action': 'endPvP', 'lost': winner_role == 'guest'})
    if guest_w:
        await send(guest_w, {'action': 'endPvP', 'lost': winner_role == 'host'})

    log.info(f"lobby {lobby['_code']} endPvP winner={winner_role} h={hs} g={gs}")

async def handle_lobby_ready(writer, msg, lobby, role):
    is_ready = msg.get('action') == 'ready'
    lobby[f'{role}_lobby_ready'] = is_ready

    # Tell the other player about this change
    enemy_w = get_enemy_writer(lobby, role)
    if enemy_w:
        await send(enemy_w, {'action': 'peer_ready', 'ready': is_ready})

    # Auto-start when both players are ready
    if (lobby['host_lobby_ready'] and lobby['guest_lobby_ready']
            and lobby.get('guest') and not lobby.get('is_in_game')):
        lobby['host_lobby_ready']  = False
        lobby['guest_lobby_ready'] = False
        await handle_start_game(lobby, 'host', {})

async def check_jimbo_stake(writer, username):
    """Auto-grant jimbo_stake once a user has all 8 vanilla stake achievements."""
    for key in VANILLA_STAKE_KEYS:
        if not db.execute(
            "SELECT 1 FROM user_entitlements ue JOIN users u ON ue.user_id=u.id "
            "WHERE u.username=? COLLATE NOCASE AND ue.key=?", (username, key)
        ).fetchone():
            return
    if grant_achievement(username, 'jimbo_stake'):
        await send(writer, {'action': 'achievementUnlocked', 'key': ACHIEVEMENT_ICONS['jimbo_stake']})

async def handle_claim_achievement(writer, msg):
    key = msg.get('key', '')
    defn = ACHIEVEMENTS.get(key)
    if not defn or defn['reserved']:
        return
    username = clients.get(writer, {}).get('username')
    if not username:
        return
    if grant_achievement(username, key):
        await send(writer, {'action': 'achievementUnlocked', 'key': ACHIEVEMENT_ICONS[key]})

async def handle_increment_achievement(writer, msg):
    key    = msg.get('key', '')
    amount = int(msg.get('count', 0))
    defn   = ACHIEVEMENTS.get(key)
    if not defn or defn['reserved'] or not defn['threshold'] or amount <= 0:
        return
    username = clients.get(writer, {}).get('username')
    if not username:
        return
    row = db.execute(
        "SELECT id FROM users WHERE username=? COLLATE NOCASE", (username,)
    ).fetchone()
    if not row:
        return
    if increment_achievement_counter(row['id'], key, amount):
        if grant_achievement(username, key):
            await send(writer, {'action': 'achievementUnlocked', 'key': ACHIEVEMENT_ICONS[key]})
        if key in VANILLA_STAKE_KEYS:
            await check_jimbo_stake(writer, username)

async def handle_fail_round(lobby, role, msg):
    if not lobby['options'].get('death_on_round_loss', True):
        return

    await lose_life(lobby, role, 'round')

    if lobby[f'{role}_lives'] <= 0:
        enemy_role = get_enemy_role(role)
        score_results = await handle_record_result(lobby, enemy_role)
        winner_msg, loser_msg = _make_gameover_msgs(lobby, enemy_role, score_results)
        enemy_w = lobby.get(enemy_role)
        my_w    = lobby[role]
        if enemy_w: await send(enemy_w, winner_msg)
        if my_w:    await send(my_w,    loser_msg)

async def handle_set_ante(lobby, role, msg):
    lobby[f'{role}_ante'] = int(msg.get('ante', 1))

async def handle_set_location(lobby, role, msg):
    location = msg.get('location', '')
    enemy_w  = get_enemy_writer(lobby, role)
    if enemy_w:
        await send(enemy_w, {'action': 'enemyLocation', 'location': location})

async def handle_new_round(lobby, role, msg):
    lobby[f'{role}_round_lives_blocker'] = False

async def handle_game_stats(lobby, role, msg):
    # Final board for the end screen. Stored per role so whichever side finishes
    # last still gets the other's; relayed straight over when both are in.
    stats = {
        'jokers':      list(msg.get('jokers') or [])[:12],
        'consumables': list(msg.get('consumables') or [])[:12],
        'deck':        msg.get('deck'),
    }
    lobby[f'{role}_stats'] = stats
    enemy_role = get_enemy_role(role)
    enemy_w = lobby.get(enemy_role)
    if enemy_w:
        await send(enemy_w, {'action': 'enemyStats', **stats})
    other = lobby.get(f'{enemy_role}_stats')
    if other:
        await send(lobby[role], {'action': 'enemyStats', **other})

async def handle_lobby_options(lobby, role, msg):
    if role != 'host':
        return
    for key in ('lives', 'seed', 'back', 'stake', 'challenge', 'gamemode', 'ruleset',
                'death_on_round_loss', 'hide_score_until_played', 'pvp_start_ante',
                'comeback_gold', 'timer_seconds', 'pvp_boss_effects'):
        if key in msg:
            lobby['options'][key] = msg[key]
    # Relay to guest so they see the config update
    guest_w = lobby.get('guest')
    if guest_w:
        await send(guest_w, {**msg, 'action': 'lobbyOptions'})

# main dispatch

# Simple peer relay actions (no server logic)
RELAY_ACTIONS = {'hello', 'chat', 'modData'}

async def dispatch(writer, msg):
    action = msg.get('action')

    # auth
    if   action == 'register':      await handle_register(writer, msg)
    elif action == 'get_salt':      await handle_get_salt(writer, msg)
    elif action == 'login':         await handle_login(writer, msg)
    elif action == 'token_login':   await handle_token_login(writer, msg)
    elif action == 'logout':        await handle_logout(writer, msg)
    elif action == 'stats':         await handle_stats(writer, msg)
    elif action == 'claimAchievement':     await handle_claim_achievement(writer, msg)
    elif action == 'incrementAchievement': await handle_increment_achievement(writer, msg)
    # heartbeat
    elif action == 'pong':
        info = clients.get(writer)
        if info is not None:
            info['_waiting_pong'] = False
    # lobby management
    elif action == 'create':        await handle_create(writer, msg)
    elif action == 'join':          await handle_join(writer, msg)
    elif action == 'rejoin_host':   await handle_rejoin_host(writer, msg)
    elif action == 'leave':
        clients[writer]['leaving'] = True
        await disconnect(writer)
    elif action in ('ready', 'unready'):
        info  = clients.get(writer)
        if not info: return
        lobby = lobbies.get(info.get('code'))
        if not lobby: return
        await handle_lobby_ready(writer, msg, lobby, info['role'])
    # lobby options (host only, relayed to guest)
    elif action in ('config', 'lobbyOptions'):
        info  = clients.get(writer)
        if not info: return
        lobby = lobbies.get(info.get('code'))
        if not lobby: return
        await handle_lobby_options(lobby, info['role'], msg)
    # game actions
    elif action in RELAY_ACTIONS:
        info  = clients.get(writer)
        if not info: return
        lobby = lobbies.get(info.get('code'))
        if not lobby: return
        msg['_from'] = info['role']
        await broadcast(lobby, msg, exclude=writer)
    elif action in ('startGame', 'readyBlind', 'unreadyBlind', 'playHand',
                    'failRound', 'setAnte', 'setLocation', 'newRound', 'gameStats'):
        info  = clients.get(writer)
        if not info: return
        lobby = lobbies.get(info.get('code'))
        if not lobby: return
        role = info['role']
        if   action == 'startGame':    await handle_start_game(lobby, role, msg)
        elif action == 'readyBlind':   await handle_ready_blind(lobby, role, msg)
        elif action == 'unreadyBlind': await handle_unready_blind(lobby, role, msg)
        elif action == 'pauseTimer':   await handle_pause_timer(lobby, role, msg)
        elif action == 'resumeTimer':  await handle_resume_timer(lobby, role, msg)
        elif action == 'playHand':     await handle_play_hand(lobby, role, msg)
        elif action == 'failRound':    await handle_fail_round(lobby, role, msg)
        elif action == 'setAnte':      await handle_set_ante(lobby, role, msg)
        elif action == 'setLocation':  await handle_set_location(lobby, role, msg)
        elif action == 'newRound':     await handle_new_round(lobby, role, msg)
        elif action == 'gameStats':    await handle_game_stats(lobby, role, msg)

# connection lifecycle

async def heartbeat_task(writer, sid):
    await asyncio.sleep(PING_INTERVAL)
    while writer in clients:
        await send(writer, {'action': 'ping'})
        clients[writer]['_waiting_pong'] = True
        await asyncio.sleep(PONG_TIMEOUT)
        if writer not in clients:
            break
        if clients[writer].get('_waiting_pong'):
            log.info(f'sid={sid} pong timeout — closing dead connection')
            try:
                writer.close()
            except Exception:
                pass
            break
        await asyncio.sleep(PING_INTERVAL - PONG_TIMEOUT)

async def handle_rejoin_host(writer, msg):
    code  = (msg.get('code') or '').upper().strip()
    lobby = lobbies.get(code)
    info  = clients.get(writer, {})

    if not lobby or lobby.get('host') is not None:
        await send(writer, {'action': 'error', 'reason': 'no_lobby'})
        return
    # Identity check: the reconnecting client must be the original host user.
    if not info.get('user_id') or info['user_id'] != lobby.get('host_user_id'):
        await send(writer, {'action': 'error', 'reason': 'no_lobby'})
        return

    lobby['host'] = writer
    lobby['_host_reconnect_deadline'] = None
    lobby['host_lobby_ready']  = False
    lobby['guest_lobby_ready'] = False
    clients[writer] = {**clients[writer], 'code': code, 'role': 'host'}
    if msg.get('mod_version'):   clients[writer]['mod_version']   = msg['mod_version']
    if msg.get('smods_version'): clients[writer]['smods_version'] = msg['smods_version']

    guest_w        = lobby.get('guest')
    guest_username = clients.get(guest_w, {}).get('username') if guest_w else None

    await send(writer, {
        'action':         'rejoined',
        'code':           code,
        'guest_username': guest_username,
        'options':        lobby.get('options', {}),
        'guest_mod_version':   clients.get(guest_w, {}).get('mod_version') if guest_w else None,
        'guest_smods_version': clients.get(guest_w, {}).get('smods_version') if guest_w else None,
    })
    if guest_w:
        await send(guest_w, {
            'action':   'peer_rejoined',
            'username': info.get('username', 'Host'),
            'mod_version':   clients[writer].get('mod_version'),
            'smods_version': clients[writer].get('smods_version'),
        })
    log.info(f'lobby {code} host rejoined')

async def handle_client(reader, writer):
    sid = os.urandom(3).hex()
    log.info(f"connect sid={sid}")
    clients[writer] = {'_seq': 0, '_waiting_pong': False}
    _write_status()

    # OS-level TCP keepalive: detect dead sockets at the network layer
    raw = writer.get_extra_info('socket')
    if raw:
        try:
            raw.setsockopt(_socket.SOL_SOCKET, _socket.SO_KEEPALIVE, 1)
            raw.setsockopt(_socket.IPPROTO_TCP, _socket.TCP_KEEPIDLE,  30)
            raw.setsockopt(_socket.IPPROTO_TCP, _socket.TCP_KEEPINTVL, 10)
            raw.setsockopt(_socket.IPPROTO_TCP, _socket.TCP_KEEPCNT,    5)
        except (AttributeError, OSError):
            pass

    hb  = asyncio.ensure_future(heartbeat_task(writer, sid))
    buf = ''
    try:
        while True:
            chunk = await reader.read(4096)
            if not chunk:
                break
            buf += chunk.decode(errors='ignore')
            if len(buf) > MSG_MAX:
                break
            while '\n' in buf:
                line, buf = buf.split('\n', 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except Exception:
                    continue
                await dispatch(writer, msg)
    except Exception as e:
        log.info(f"error sid={sid}: {e}")
    finally:
        hb.cancel()
        await disconnect(writer)
        try:
            writer.close()
        except Exception:
            pass
        log.info(f"disconnect sid={sid}")

async def disconnect(writer):
    info = clients.pop(writer, None)
    _write_status()
    if not info:
        return
    code  = info.get('code')
    lobby = lobbies.get(code) if code else None
    if not lobby:
        return

    intentional = info.get('leaving', False)
    in_game     = lobby.get('is_in_game', False)
    role        = info.get('role')

    await broadcast(lobby, {'action': 'peer_left'}, exclude=writer)
    if in_game:
        await broadcast(lobby, {'action': 'stopGame'}, exclude=writer)

    if intentional or in_game:
        del lobbies[code]
        log.info(f"lobby {code} closed (role={role} intentional={intentional})")
    elif role == 'guest':
        # Guest dropped: keep lobby so they can rejoin within 120 s
        if lobby.get('guest') is writer:
            lobby['guest'] = None
        lobby['host_lobby_ready']  = False
        lobby['guest_lobby_ready'] = False
        lobby['_reconnect_deadline'] = now() + 120
        log.info(f"lobby {code} guest dropped, held for reconnect")
    else:
        # Host dropped unintentionally: keep lobby so host can rejoin within HOST_TTL
        lobby['host'] = None
        lobby['host_lobby_ready']  = False
        lobby['guest_lobby_ready'] = False
        lobby['_host_reconnect_deadline'] = now() + HOST_TTL
        log.info(f"lobby {code} host dropped, held {HOST_TTL}s for reconnect")

# entry

async def periodic_cleanup():
    while True:
        await asyncio.sleep(60)
        cleanup_stale()
        _write_status()

async def entitlement_sync_task():
    while True:
        await asyncio.sleep(8)
        for writer, info in list(clients.items()):
            username = info.get('username')
            if not username:
                continue
            current = set(get_user_entitlements(username))
            sent    = info.get('_sent_entitlements', set())
            new_keys = current - sent
            for key in new_keys:
                await send(writer, {'action': 'entitlementGranted', 'key': key})
            if new_keys:
                info['_sent_entitlements'] = sent | new_keys

async def main():
    srv = await asyncio.start_server(handle_client, HOST, PORT)
    log.info(f"listening on {HOST}:{PORT}")
    async with srv:
        asyncio.ensure_future(periodic_cleanup())
        asyncio.ensure_future(entitlement_sync_task())
        await srv.serve_forever()

asyncio.run(main())

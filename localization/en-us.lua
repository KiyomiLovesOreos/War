-- War mod localisation — English (en-us)
-- All user-visible strings live here; UI files call localize('war_key').
-- SMODS merges this into G.localization at load time.

return {
    -- SMODS object descriptions
    descriptions = {
        Mod = {
            War = {
                name = "War",
                text = {
                    "The best Balatro PvP",
                },
            },
        },
        -- Player icons (see WAR.ICONS in core/avatar.lua).
        -- No individual names — all display as "Your Rival" and are replaced
        -- in-run with the actual rival username.
        WAR_Icon = {
            -- Free
            war_icon_jimbo            = { name = "Jimbo", },
            war_icon_blueprint        = { name = "Blueprint" },
            war_icon_brainstorm       = { name = "Brainstorm" },
            war_icon_verity           = { name = "Verity" },
            war_icon_sock_and_buskin  = { name = "Sock and Buskin" },
            war_icon_photograph       = { name = "Photograph" },
            war_icon_drool            = { name = "Drool" },
            war_icon_stencil          = { name = "Stencil" },
            war_icon_spades           = { name = "Spades" },
            war_icon_hearts           = { name = "Hearts" },
            war_icon_clubs            = { name = "Clubs" },
            war_icon_diamonds         = { name = "Diamonds" },
            war_icon_spades_hc        = { name = "Spades (High Contrast)" },
            war_icon_hearts_hc        = { name = "Hearts (High Contrast)" },
            war_icon_clubs_hc         = { name = "Clubs (High Contrast)" },
            war_icon_diamonds_hc      = { name = "Diamonds (High Contrast)" },
            war_icon_ralsei           = { name = "Ralsei" },
            war_icon_eight_ball       = { name = "8-Ball" },
            war_icon_even_steven      = { name = "Even Steven" },
            war_icon_odd_todd         = { name = "Odd Todd" },
            war_icon_missing          = { name = "Missing" },
            war_icon_azure            = { name = "Azure" },
            war_icon_flowery          = { name = "Flowery" },
            war_icon_pig              = { name = "Pig" },
            war_icon_persona          = { name = "Persona" },
            war_icon_raised_fist      = { name = "Raised Fist" },
            war_icon_popcorn          = { name = "Popcorn" },
            war_icon_gift_card        = { name = "Gift Card" },
            war_icon_stamp            = { name = "Stamp" },
            war_icon_superposition    = { name = "Superposition" },
            war_icon_fibonacci        = { name = "Fibonacci" },
            war_icon_scholar          = { name = "Scholar" },
            war_icon_ride_the_bus     = { name = "Ride the Bus" },
            war_icon_pareidolia       = { name = "Pareidolia" },
            war_icon_brutalists_heart = { name = "Brutalists Heart" },
            war_icon_chud             = { name = "Chud" },
            war_icon_sob              = { name = "Sob" },
            war_icon_tasque_manager   = { name = "Tasque Manager" },
            war_icon_hack             = { name = "Hack" },
            war_icon_hit_the_road     = { name = "Hit the Road" },

            -- Achievement
            war_icon_jolly            = { name = "Jolly", text = { "Win a game playing only hands that contain a pair" } },
            war_icon_oops             = { name = "Oops", text = { "Have 25 probability rolls land in one game" } },
            war_icon_droll            = { name = "Droll", text = { "Win a game playing only hands that contain a flush" } },
            war_icon_meta             = { name = "Meta", text = { "Play 100 matches" } },
            war_icon_brilliant        = { name = "Brilliant", text = { "Win 10 games" } },
            war_icon_blunder          = { name = "Blunder", text = { "Lose 10 games" } },
            war_icon_the_soul         = { name = "The Soul", text = { "Use The Soul in a game" } },
            war_icon_oneshot          = { name = "OneShot", text = { "Use The Sun 100 times" } },
            war_icon_egg              = { name = "Egg", text = { "Sell a joker worth $15 or more" } },
            war_icon_bloodstone       = { name = "Bloodstone", text = { "Score 100 heart cards" } },
            war_icon_pizza            = { name = "Pizza", text = { "Score 100 red seal cards" } },
            war_icon_riff_raff        = { name = "Riff Raff", text = { "Win a game using only Common jokers" } },
            war_icon_garygpt          = { name = "GaryGPT", text = { "Destroy the Splash Joker in a match" } },
            war_icon_missing_joker    = { name = "Missing Joker", text = { "Win a game without filling your joker slots" } },
            war_icon_cola             = { name = "Cola", text = { "Have 5 tags at once in a game" } },
            war_icon_osage            = { name = "Osage", text = { "Score 1,000 Stone cards" } },
            war_icon_stone            = { name = "Stone", text = { "Score 100 Stone cards" } },
            war_icon_gold             = { name = "Gold", text = { "Trigger the effect of Gold cards 100 times" } },
            war_icon_steel            = { name = "Steel", text = { "Trigger the effect of Steel cards 100 times" } },
            war_icon_wild             = { name = "Wild", text = { "Score 100 Wild cards" } },
            war_icon_mult             = { name = "Mult", text = { "Score 100 Mult cards" } },
            war_icon_lucky            = { name = "Lucky", text = { "Trigger the effect of Lucky cards 100 times" } },
            war_icon_white_stake      = { name = "White Stake", text = { "Play 10 matches on the White Stake" } },
            war_icon_red_stake        = { name = "Red Stake", text = { "Play 10 matches on the Red Stake" } },
            war_icon_green_stake      = { name = "Green Stake", text = { "Play 10 matches on the Green Stake" } },
            war_icon_blue_stake       = { name = "Blue Stake", text = { "Play 10 matches on the Blue Stake" } },
            war_icon_black_stake      = { name = "Black Stake", text = { "Play 10 matches on the Black Stake" } },
            war_icon_purple_stake     = { name = "Purple Stake", text = { "Play 10 matches on the Purple Stake" } },
            war_icon_orange_stake     = { name = "Orange Stake", text = { "Play 10 matches on the Orange Stake" } },
            war_icon_gold_stake       = { name = "Gold Stake", text = { "Play 10 matches on the Gold Stake" } },
            war_icon_jimbo_stake      = { name = "Jimbo Stake", text = { "Play 10 matches on every vanilla Stake" } },
            war_icon_red_deck         = { name = "Red Deck", text = { "Play 10 matches on the Red Deck" } },
            war_icon_blue_deck        = { name = "Blue Deck", text = { "Play 10 matches on the Blue Deck" } },
            war_icon_yellow_deck      = { name = "Yellow Deck", text = { "Play 10 matches on the Yellow Deck" } },
            war_icon_green_deck       = { name = "Green Deck", text = { "Play 10 matches on the Green Deck" } },
            war_icon_black_deck       = { name = "Black Deck", text = { "Play 10 matches on the Black Deck" } },
            war_icon_ghost_deck       = { name = "Ghost Deck", text = { "Play 10 matches on the Ghost Deck" } },
            war_icon_painted_deck     = { name = "Painted Deck", text = { "Play 10 matches on the Painted Deck" } },
            war_icon_plasma_deck      = { name = "Plasma Deck", text = { "Play 10 matches on the Plasma Deck" } },
            war_icon_red_seal         = { name = "Red Seal", text = { "Trigger the Red Seal 100 times" } },
            war_icon_blue_seal        = { name = "Blue Seal", text = { "Trigger the Blue Seal 100 times" } },
            war_icon_gold_seal        = { name = "Gold Seal", text = { "Trigger the Gold Seal 100 times" } },
            war_icon_purple_seal      = { name = "Purple Seal", text = { "Trigger the Purple Seal 100 times" } },
            war_icon_eyes             = { name = "Eyes", text = { "Eyes" } },
            war_icon_supernova        = { name = "Supernova", text = { "Supernova" } },

            -- Special
            war_icon_bean             = { name = "Bean" },
            war_icon_zaino            = { name = "Zaino" },
            war_icon_thunderedge      = { name = "ThunderEdge" },
            war_icon_doc              = { name = "Doc" },
            war_icon_murphy           = { name = "Murphy" },
            war_icon_soulware         = { name = "Soulware" },
            war_icon_sheila           = { name = "Sheila" },
            war_icon_astra            = { name = "Astra" },
            war_icon_lizie            = { name = "lizie" },
            war_icon_inky             = { name = "Inky" },
            war_icon_revo             = { name = "Revo" },
            war_icon_argel            = { name = "Argel" },
            war_icon_baggute          = { name = "Baggute" },
            war_icon_amolyte          = { name = "Amolyte" },
            war_icon_gabby            = { name = "Gabby" },
        },
        Blind = {},
    },

    misc = {
        dictionary = {
            -- Main menu / navigation
            war_discord         = "Join Discord",
            war_single_player   = "Single Player",
            war_online          = "Online",

            -- Private lobby screens
            war_join_lobby            = "Join Lobby",
            war_create_lobby          = "Create Lobby",
            war_lobby_code_prompt     = "Lobby Code",
            war_paste_code            = "Paste Code",
            war_join                  = "Join",

            -- Gamemode / ruleset selection
            war_gamemodes             = "Gamemodes",
            war_rulesets              = "Rulesets",
            war_next                  = "Next",

            -- Gamemode: Vanilla
            war_gm_vanilla_name   = "Vanilla",
            war_gm_vanilla_desc   = {
                "Standard PvP Balatro.",
                "Boss blinds become PvP rounds",
                "starting from Ante 2.",
                "Score fewer chips to lose a life.",
            },

            -- Ruleset: Standard
            war_rs_standard_name   = "Standard",
            war_rs_standard_desc   = {"Default ruleset.", "No extra restrictions."},

            -- Ruleset: Mini World
            war_rs_weeworld_name   = "Wee World",
            war_rs_weeworld_desc   = {"Removes majority of all", "Jokers, Consumables, Booster Packs and Vouchers."},

            -- Lobby bar buttons
            war_ready                 = "READY",
            war_unready               = "UNREADY",
            war_lobby_settings        = "LOBBY SETTINGS",
            war_deck_stake            = "DECK & STAKE",
            war_players               = "PLAYERS",
            war_code                  = "CODE",
            war_leave                 = "LEAVE",

            -- Lobby status line
            war_status_waiting        = "Waiting for opponent",
            war_status_connected      = "Opponent connected",
            war_version_mismatch      = "Build mismatch - one of you is out of date",
            war_end_board_waiting     = "board loading...",
            war_end_board_empty       = "no jokers",
            war_status_you_ready      = "Waiting for opponent...",
            war_status_opp_ready      = "Opponent is ready!",
            war_status_starting       = "Starting!",
            war_stake                 = "Stake ",

            -- Code popup
            war_code_label            = "Lobby Code",
            war_reveal                = "Click to Reveal",
            war_copy                  = "Copy to Clipboard",

            -- Options popup
            war_host_only             = "Only the host can change settings",
            war_score_new_record      = "New record!",
            war_score_tied            = "Tied your best!",
            war_score_best            = "Best:",
            war_tab_icons_free        = "Default",
            war_tab_icons_achievement = "Achievements",
            war_tab_icons_special     = "Special",
            war_tab_general           = "General",
            war_tab_gameplay          = "Gameplay",
            war_tab_bans              = "Bans",
            war_opt_lives             = "Starting Lives",
            war_opt_timer             = "Timer",
            war_opt_boss_effects      = "PvP Boss Effects",
            war_opt_pvp_ante          = "PvP Start Ante",
            war_opt_death_round       = "Death on Round Loss",
            war_opt_hide_score        = "Hide Score Until Played",
            war_opt_comeback_gold     = "Comeback Bonus",

            -- In-run cash-out
            war_comeback_bonus        = "Comeback",

            -- Achievement unlock notifications
            war_achievement_unlocked  = "Achievement Unlocked",

            -- Ruleset bans
            war_bans_title            = "What this ruleset bans",
            war_view_bans             = "VIEW BANS",
            war_bans_jokers           = "Banned Jokers",
            war_bans_consumables      = "Banned Consumables",
            war_bans_vouchers         = "Banned Vouchers",
            war_bans_enhancements     = "Banned Enhancements",
            war_bans_tags             = "Banned Tags",
            war_bans_blinds           = "Banned Blinds",
            war_bans_none             = "Nothing is banned",

            -- Players popup
            war_players_title         = "Players in Lobby",
            war_role_host             = "Host",
            war_role_guest            = "Guest",
            war_waiting_ellipsis      = "Waiting...",

            -- Connection status indicator
            war_cs_in_lobby           = "In Lobby",
            war_cs_connected          = "Connected",
            war_cs_offline            = "Offline",

            -- Lobby side panels
            war_panel_players         = "Players",
            war_panel_spectators      = "Spectators",
            war_panel_deck            = "Deck",
            war_panel_stake           = "Stake",
            war_panel_seed            = "Seed",
            war_panel_seed_random     = "Random Seed",
            war_panel_lives_label     = "lives",
            war_panel_timer_off       = "Timer: Off",
            war_panel_timer_label     = "Timer",
            war_timer_off             = "Off",
            war_blind_hurry           = "Opponent is waiting — select the blind!",
            war_timeout_you           = "Timed out! You lost a life.",
            war_timeout_enemy         = "Opponent timed out! They lost a life.",
            war_panel_challenge       = "Challenge",
            war_select_cap            = "SELECT",
            war_end_ante              = "Ante",
            war_end_new_record        = "New Record!",
            war_end_view_mine         = "My Board",
            war_end_view_opp          = "Their Board",
            war_end_opponent          = "Opponent",

            -- In-run HUD
            war_hud_lives             = "Lives",
            war_round_timer           = "Timer",
            war_round_paused          = "Paused",
            war_hud_enemy_score       = "Enemy Score",
            war_hud_enemy_hands       = "Enemy Hands ",
            war_life_lost             = "life lost!",
            war_rival_life_lost       = "Rival lost a life",
            war_wait_enemy            = "Waiting for opponent...",

            -- PvP round popup
            war_pvp_waiting           = "Waiting for opponent...",
            war_round_won             = "Round Won!",
            war_round_lost            = "Round Lost!",
            war_you_scored_more       = "Your opponent scored fewer chips.",
            war_you_scored_less       = "Your opponent scored more chips.",
            war_lives_you             = "Your lives: ",
            war_lives_opp             = "Opponent: ",
            war_continue              = "Continue",

            -- End-game popup
            war_defeated_opp          = "You defeated your opponent!",
            war_better_luck           = "Better luck next time.",
            war_back_to_menu          = "Back to Menu",
            war_ok                    = "OK",

            -- Error / info messages
            war_could_not_join        = "Could not join: ",
            war_could_not_create      = "Could not create: ",
            war_disconnected          = "Disconnected from lobby.",
            war_relay_lost            = "Lost connection to relay.",
            war_server_error          = "Server error.",
            war_game_stopped          = "Game stopped.",
            war_opp_disconnected      = "Opponent disconnected.",
            war_opp_left              = "Opponent left the game.",

            -- Server error codes (see WAR.ERROR_KEYS)
            war_err_missing_fields    = "Missing username or password.",
            war_err_bad_username      = "Invalid username.",
            war_err_username_taken    = "That username is taken.",
            war_err_bad_credentials   = "Wrong username or password.",
            war_err_invalid_token     = "Session expired. Log in again.",
            war_err_no_user           = "Not logged in.",
            war_err_no_lobby          = "Lobby not found.",
            war_err_lobby_full        = "Lobby is full.",

            -- Deck selector
            -- Replaces vanilla "PLAY" button text while WAR._deck_selecting is active.
            war_select                = "SELECT",

            -- Account screens
            war_account_label         = "Account: ",
            war_manage_account        = "Manage Account",
            war_current_account       = "Current: ",
            war_log_in                = "Log In",
            war_register              = "Register",
            war_log_out               = "Log Out",
            war_close                 = "Close",
            war_create_account        = "Create Account",
            war_username_prompt       = "Username",
            war_password_prompt       = "Password",
            war_confirm_pass_prompt   = "Confirm Password",
            war_logout_confirm        = "Log out of account?",
            war_yes_log_out           = "Yes",
            war_no_stay               = "No",
            war_none                  = "None",

            -- Mod config screens
            war_icon                  = "Icon",
        }
    }
}

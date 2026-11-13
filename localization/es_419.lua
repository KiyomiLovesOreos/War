-- War mod localisation —Latin American Spanish (es-419)
-- All user-visible strings live here; UI files call localize('war_key').
-- SMODS merges this into G.localization at load time.

return {
    -- SMODS object descriptions
    descriptions = {
        Mod = {
            War = {
                name = "War",
                text = {
                    "Mi propia version de Balatro MJ,",
                    "pero tipo, sin IA.",
                },
            },
        },
        -- Player icons (see WAR.ICONS in core/avatar.lua).
        -- No individual names — all display as "Your Rival" and are replaced
        -- in-run with the actual rival username.
        Icon = {},
        Blind = {},
    },

    misc = {
        dictionary = {
            -- Main menu / navigation
            war_single_player   = "Un Jugador",
            war_online          = "En linea",

            -- Private lobby screens
            war_join_lobby      = "Unirse a un Lobby",
            war_create_lobby    = "Crear un Lobby",
            war_lobby_code_prompt = "Código del Lobby",
            war_paste_code      = "Pegar Código",
            war_join            = "Unirse",

            -- Gamemode / ruleset selection
            war_gamemodes       = "Modos de Juego",
            war_rulesets        = "Sets de Reglas",
            war_next            = "Siguiente",


            -- Gamemode: Vanilla
            war_gm_vanilla_name   = "Regular",
            war_gm_vanilla_desc   = {
                "Balatro PvP Regular.",
                "Las ciegas jefe se convierten en",
                "rondas PvP empezando de Ante 2.",
                "Puntua menos fichas para perder una vida.",
            },

            -- Ruleset: Standard
            war_rs_standard_name   = "Regular",
            war_rs_standard_desc   = {"Set de reglas predeterminado.", "Sin restricciones extra."},

            -- Ruleset: Wee World
            war_rs_weeworld_name   = "Wee World",
            war_rs_weeworld_desc   = {"Removes half of all", "Jokers and Consumables."},

            -- Lobby bar buttons
            war_ready           = "LISTO",
            war_unready         = "NO LISTO",
            war_lobby_settings  = "CONFIGURACIÓN DEL LOBBY",
            war_deck_stake      = "BARAJA Y POZO",
            war_players         = "JUGADORES",
            war_code            = "CÓDIGO",
            war_leave           = "SALIR",

            -- Lobby status line
            war_status_waiting      = "Esperando al oponente",
            war_status_connected    = "Oponente conectado",
            war_version_mismatch    = "Error de version - uno de ustedes esta desactualizado",
            war_end_board_waiting   = "cargando comodines...",
            war_end_board_empty     = "sin comodines",
            war_status_you_ready    = "esperando",
            war_status_opp_ready    = "El oponente esta Listo!",
            war_status_starting     = "Empezando!",
            war_stake               = "Pozo ",

            -- Code popup
            war_code_label      = "Código del Lobby",
            war_reveal          = "Click para Revelar",
            war_copy            = "Copiar a el portapapeles",

            -- Options popup
            war_host_only       = "Solo el anfitrión puede cambiar la configuración",
            war_score_new_record = "Nuevo Record!",
            war_score_tied       = "Empataste tu mejor puntaje!",
            war_score_best       = "Mejor:",
            war_tab_icons_free        = "Predeterminado",
            war_tab_icons_achievement = "Logros",
            war_tab_icons_special     = "Especial",
            war_tab_general     = "General",
            war_tab_gameplay    = "Jugabilidad",
            war_tab_bans        = "Desabilitaciones",
            war_opt_lives       = "Vidas Iniciales",
            war_opt_timer       = "Tiempo",
            war_opt_boss_effects = "Efectos del Jefe PvP",
            war_opt_pvp_ante    = "Ante PvP Inicial",
            war_opt_death_round = "Muerte en Ronda Perdida",
            war_opt_hide_score  = "Esconder fichas hasta jugar",
            war_opt_comeback_gold = "Bonus de remontada",

            -- In-run cash-out
            war_comeback_bonus  = "Remontada",

            -- Achievement unlock notifications
            war_achievement_unlocked = "Logro Desbloqueado!",

            -- Icon names and unlock conditions, one per key in DEV/icon_order.md.
            -- Free icons show a name; gated icons show what unlocks them.
            war_icon_jimbo           = "Jimbo",
            war_icon_blueprint       = "Plano",
            war_icon_brainstorm      = "Lluvia de ideas",
            war_icon_verity          = "Verity",
            war_icon_sock_and_buskin = "Tragedia y comedia",
            war_icon_photograph      = "Fotografía",
            war_icon_drool           = "Babeo",
            war_icon_stencil         = "Plantilla",
            war_icon_spades          = "Picas",
            war_icon_hearts          = "Corazones",
            war_icon_clubs           = "Treboles",
            war_icon_diamonds        = "Diamantes",
            war_icon_spades_hc       = "Picas (Alto Contraste)",
            war_icon_hearts_hc       = "Corazones (Alto Contraste)",
            war_icon_clubs_hc        = "Treboles (Alto Contraste)",
            war_icon_diamonds_hc     = "Diamantes (Alto Contraste)",
            war_icon_ralsei          = "Ralsei",
            war_icon_eight_ball      = "Bola 8",
            war_icon_even_steven     = "El par",
            war_icon_odd_todd        = "El impar",
            war_icon_missing         = "No encontrado",
            war_icon_azure           = "Azure",
            war_icon_flowery         = "Flowery",
            war_icon_pig             = "Cerdo",
            war_icon_persona         = "Persona",
            war_icon_raised_fist     = "Puño elevado",
            war_icon_popcorn         = "Palomitas de maíz",
            war_icon_gift_card       = "Tarjeta de regalo",
            war_icon_stamp           = "Estampa",
            war_icon_superposition   = "Superposición",
            war_icon_fibonacci       = "Fibonacci",
            war_icon_scholar         = "Erudito",
            war_icon_ride_the_bus    = "Al autobus",
            war_icon_pareidolia      = "Pareidolia",
            war_icon_brutalists_heart = "Corazon del brutalista",
            war_icon_chud             = "Chud",
            war_icon_sob              = "Llorozo",
            war_icon_tasque_manager   = "Administrador de tareas",
            war_icon_hack             = "Comediante",
            war_icon_hit_the_road     = "Al camino",

            war_icon_jolly           = "Gana una partida jugando solamente manos que contengan un par",
            war_icon_oops            = "Consigue acertar 25 probabilidades en una sola partida",
            war_icon_droll           = "Gana una partida jugando solamente manos que contengan un color",
            war_icon_meta            = "Juega 100 partidas",
            war_icon_brilliant       = "Gana 10 partidas",
            war_icon_blunder         = "Pierde 10 partidas",
            war_icon_the_soul        = "Usa El Alma en una partida",
            war_icon_oneshot         = "Usa El Sol 100 veces",
            war_icon_egg             = "Vende un comodin que valga $15 o más",
            war_icon_bloodstone      = "Puntua 100 cartas de corazón",
            war_icon_pizza           = "Puntua 100 cartas con un sello rojo",
            war_icon_riff_raff       = "Gana una partida usando solo comodines comunes",
            war_icon_garygpt         = "Destruye el comodin Salpicadura en una partida",
            war_icon_missing_joker   = "Gana una partida sin llenar tus ranuras de comodines",
            war_icon_cola            = "Manten 5 etiquetas a la vez en una partida",
            war_icon_osage           = "Puntua 1.000 cartas de piedra",
            war_icon_stone           = "Puntua 100 cartas de piedra",
            war_icon_gold            = "Activa el efecto de cartas de oro 100 veces",
            war_icon_steel           = "Activa el efecto de cartas de acero 100 veces",
            war_icon_wild            = "Puntua 100 cartas versatiles",
            war_icon_mult            = "Puntua 100 cartas multi",
            war_icon_lucky           = "Activa el efecto de cartas de la suerte 100 veces",
            war_icon_white_stake     = "Juega 10 partidas en el pozo blanco",
            war_icon_red_stake       = "Juega 10 partidas en el pozo rojo",
            war_icon_green_stake     = "Juega 10 partidas en el pozo verde",
            war_icon_blue_stake      = "Juega 10 partidas en el pozo azul",
            war_icon_black_stake     = "Juega 10 partidas en el pozo negro",
            war_icon_purple_stake    = "Juega 10 partidas en el pozo morado",
            war_icon_orange_stake    = "Juega 10 partidas en el pozo naranja",
            war_icon_gold_stake      = "Juega 10 partidas en el pozo dorado",
            war_icon_jimbo_stake     = "Juega 10 partidas en todos los pozos vanilla",
            war_icon_red_deck        = "Juega 10 partidas en la baraja roja",
            war_icon_blue_deck       = "Juega 10 partidas en la baraja azul",
            war_icon_yellow_deck     = "Juega 10 partidas en la baraja amarilla",
            war_icon_green_deck      = "Juega 10 partidas en la baraja verde",
            war_icon_black_deck      = "Juega 10 partidas en la baraja negra",
            war_icon_ghost_deck      = "Juega 10 partidas en la baraja fantasma",
            war_icon_painted_deck    = "Juega 10 partidas en la baraja pintada",
            war_icon_plasma_deck     = "Juega 10 partidas en la baraja plasma",
            war_icon_red_seal        = "Activa el sello rojo 100 veces",
            war_icon_blue_seal       = "Activa el sello azul 100 veces",
            war_icon_gold_seal       = "Activa el sello dorado 100 veces",
            war_icon_purple_seal     = "Activa el sello morado 100 veces",
            war_icon_eyes            = "Ojos",
            war_icon_supernova       = "Supernova",

            war_icon_bean            = "Bean",
            war_icon_zaino           = "Zaino",
            war_icon_thunderedge     = "ThunderEdge",
            war_icon_doc             = "Doc",
            war_icon_murphy          = "Murphy",
            war_icon_soulware        = "Soulware",
            war_icon_sheila          = "Sheila",
            war_icon_astra           = "Astra",
            war_icon_lizie           = "lizie",
            war_icon_inky            = "Inky",
            war_icon_revo            = "Revo",
            war_icon_argel           = "Argel",
            war_icon_baggute         = "Baggute",
            war_icon_amolyte         = "Amolyte",
            war_icon_gabby           = "Gabby",

            -- Ruleset bans
            war_bans_title        = "Lo que desabilita este set de reglas",
            war_view_bans         = "VER DESHABILITACIONES",
            war_bans_jokers       = "Comodines deshabilitados",
            war_bans_consumables  = "Consumibles deshabilitados",
            war_bans_vouchers     = "Vales deshabilitados",
            war_bans_enhancements = "Mejoras deshabilitadas",
            war_bans_tags         = "Etiquetas deshabilitadas",
            war_bans_blinds       = "Ciegas deshabilitadas",
            war_bans_none         = "Nada esta deshabilitado",

            -- Players popup
            war_players_title   = "Jugadores en el Lobby",
            war_role_host       = "Anfitrión",
            war_role_guest      = "Invitado",
            war_waiting_ellipsis = "Esperando...",

            -- Connection status indicator
            war_cs_in_lobby  = "En el Lobby",
            war_cs_connected = "Connectado",
            war_cs_offline   = "Fuera de linea",

            -- Lobby side panels
            war_panel_players     = "Jugadores",
            war_panel_spectators  = "Espectadores",
            war_panel_deck        = "Baraja",
            war_panel_stake       = "Pozo",
            war_panel_seed        = "Semilla",
            war_panel_seed_random = "Semilla aleatoria",
            war_panel_lives_label = "vidas",
            war_panel_timer_off   = "Tiempo: Deshabilitado",
            war_panel_timer_label = "Tiempo",
            war_timer_off         = "No",
            war_blind_hurry       = "El oponente esta esperando - selecciona la ciega!",
            war_timeout_you       = "Se acabo el tiempo! Perdiste una vida",
            war_timeout_enemy     = "El oponente se quedo sin tiempo! Perdieron una vida.",
            war_panel_challenge   = "Desafio",
            war_select_cap        = "SELECCIONAR",
            war_end_ante          = "Ante",
            war_end_new_record      = "Nuevo record!",
            war_end_view_mine       = "Mis comodines",
            war_end_view_opp        = "Sus comodines",
            war_end_opponent      = "Oponente",

            -- In-run HUD
            war_hud_lives       = "Vidas",
            war_round_timer     = "Tiempo",
            war_round_paused    = "Pausado",
            war_hud_enemy_score = "Puntaje enemigo",
            war_hud_enemy_hands = "Manos enemigas ",
            war_life_lost       = "vida perdida!",
            war_rival_life_lost = "El rival perdio una vida",
            war_wait_enemy      = "Esperando al oponente...",

            -- PvP round popup
            war_pvp_waiting     = "Esperando al oponente...",
            war_round_won       = "Ronda Ganada!",
            war_round_lost      = "Ronda Perdida!",
            war_you_scored_more = "Tu oponente puntuo menos fichas.",
            war_you_scored_less = "Tu oponente puntuo más fichas.",
            war_lives_you       = "Your lives: ",
            war_lives_opp       = "Oponente: ",
            war_continue        = "Continuar",

            -- End-game popup
            war_defeated_opp    = "Derrotaste a tu oponente!",
            war_better_luck     = "Mejor suerte la proxima.",
            war_back_to_menu    = "Volver al Menu",
            war_ok              = "OK",

            -- Error / info messages
            war_could_not_join      = "No se pudo unir: ",
            war_could_not_create    = "No se pudo crear: ",
            war_disconnected        = "Desconectado del Lobby.",
            war_relay_lost          = "Connexion perdida.",
            war_server_error        = "Error de servidor.",
            war_game_stopped        = "Juego detenido.",
            war_opp_disconnected    = "El oponente se ha desconectado.",
            war_opp_left            = "El oponente se salio del juego.",

            -- Server error codes (see WAR.ERROR_KEYS)
            war_err_missing_fields  = "Nombre o contraseña faltante/s.",
            war_err_bad_username    = "Nombre invalido.",
            war_err_username_taken  = "Ese nombre ya esta en uso.",
            war_err_bad_credentials = "Nombre o contraseña incorrecta/s.",
            war_err_invalid_token   = "Sesión expirada. Inicia sesión de vuelta.",
            war_err_no_user         = "No ha iniciado sesión.",
            war_err_no_lobby        = "Lobby no encontrado.",
            war_err_lobby_full      = "El Lobby esta lleno.",

            -- Deck selector
            -- Replaces vanilla "PLAY" button text while WAR._deck_selecting is active.
            war_select          = "SELECCIONAR",

            -- Account screens
            war_account_label       = "Cuenta: ",
            war_manage_account      = "Administrar Cuenta",
            war_current_account     = "Actual: ",
            war_log_in              = "Iniciar sesión",
            war_register            = "Registrarse",
            war_log_out             = "Cerrar Sesión",
            war_close               = "Cerrar",
            war_create_account      = "Crear Cuenta",
            war_username_prompt     = "Nombre",
            war_password_prompt     = "Contraseña",
            war_confirm_pass_prompt = "Confirmar Contraseña",
            war_logout_confirm      = "Salir de la cuenta?",
            war_yes_log_out         = "Si",
            war_no_stay             = "No",
            war_none                = "Ninguno",

            -- Mod config screens
            war_icon                = "Icono",
        }
    }
}

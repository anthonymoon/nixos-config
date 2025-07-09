# Universal Display Manager Configuration
# Lightweight wayland-first setup with greetd + tuigreet + dwl

{ config, lib, pkgs, ... }:

{
  # Enable X11 for compatibility but prefer Wayland
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # greetd with tuigreet as the display manager
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd ${pkgs.dwl}/bin/dwl";
        user = "greeter";
      };
    };
  };

  # dwl - The lightest wayland tiling window manager
  environment.systemPackages = with pkgs; [
    # Window manager
    dwl                     # Lightweight wayland tiling WM
    
    # Essential wayland utilities
    wayland                 # Wayland core
    wlroots                 # Wayland compositor library
    xwayland                # X11 compatibility layer
    
    # Terminal and utilities
    foot                    # Lightweight wayland terminal
    fuzzel                  # Wayland application launcher
    wl-clipboard            # Wayland clipboard utilities
    wlr-randr              # Display configuration
    waybar                  # Lightweight status bar
    
    # Display manager
    greetd.tuigreet        # TUI greeter
    
    # Basic utilities
    brightnessctl          # Brightness control
    pulseaudio            # Audio control
    
    # File manager
    lf                    # Lightweight file manager
    
    # Notifications
    libnotify             # Notification library
    dunst                 # Lightweight notification daemon
  ];

  # Configure dwl
  environment.etc."dwl/config.h".text = ''
    /* Taken from https://github.com/djpohly/dwl/blob/main/config.def.h */
    #define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                            ((hex >> 16) & 0xFF) / 255.0f, \
                            ((hex >> 8) & 0xFF) / 255.0f, \
                            (hex & 0xFF) / 255.0f }
    /* appearance */
    static const int sloppyfocus               = 1;  /* focus follows mouse */
    static const int bypass_surface_visibility = 0;  /* 1 means idle inhibitors will disable idle tracking even if it's surface isn't visible  */
    static const unsigned int borderpx         = 1;  /* border pixel of windows */
    static const float rootcolor[]             = COLOR(0x222222ff);
    static const float bordercolor[]           = COLOR(0x444444ff);
    static const float focuscolor[]            = COLOR(0x005577ff);
    static const float urgentcolor[]           = COLOR(0xff0000ff);
    /* To conform the xdg-protocol, set the alpha to zero to restore the old behavior */
    static const float fullscreen_bg[]        = {0.1f, 0.1f, 0.1f, 1.0f}; /* You can also use glsl colors */

    /* tagging - TAGCOUNT must be no greater than 31 */
    #define TAGCOUNT (9)
    static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

    /* logging */
    static int log_level = WLR_ERROR;

    /* NOTE: ALWAYS keep a rule declared even if you don't use rules (e.g leave at least one example) */
    static const Rule rules[] = {
      /* app_id             title       tags mask     isfloating   monitor */
      { "Gimp_EXAMPLE",     NULL,       0,            1,           -1 }, /* Start on currently visible tags floating, not tiled */
      { "firefox_EXAMPLE",  NULL,       1 << 8,       0,           -1 }, /* Start on ONLY tag "9" */
    };

    /* layout(s) */
    static const Layout layouts[] = {
      /* symbol     arrange function */
      { "[]=",      tile },
      { "><>",      NULL },    /* no layout function means floating behavior */
      { "[M]",      monocle },
    };

    /* monitors */
    /* (x=-1, y=-1) is reserved as an "autoconfigure" monitor position indicator
     * WARNING: negative values other than (-1, -1) cause problems with Xwayland clients
     * https://gitlab.freedesktop.org/xorg/xserver/-/issues/899
     */
    /* NOTE: ALWAYS add a fallback rule, even if you are completely sure it won't be used */
    static const MonitorRule monrules[] = {
      /* name       mfact  nmaster scale layout       rotate/reflect                x    y */
      { "X11-1",    0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
      { NULL,       0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
    };

    /* keyboard */
    static const struct xkb_rule_names xkb_rules = {
      /* can specify fields: rules, model, layout, variant, options */
      /* example:
      .options = "ctrl:nocaps",
      */
      .options = NULL,
    };

    static const int repeat_rate = 25;
    static const int repeat_delay = 600;

    /* Trackpad */
    static const int tap_to_click = 1;
    static const int tap_and_drag = 1;
    static const int drag_lock = 1;
    static const int natural_scrolling = 0;
    static const int disable_while_typing = 1;
    static const int left_handed = 0;
    static const int middle_button_emulation = 0;
    /* You can choose between:
    LIBINPUT_CONFIG_SCROLL_NO_SCROLL
    LIBINPUT_CONFIG_SCROLL_2FG
    LIBINPUT_CONFIG_SCROLL_EDGE
    LIBINPUT_CONFIG_SCROLL_ON_BUTTON_DOWN
    */
    static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;

    /* You can choose between:
    LIBINPUT_CONFIG_CLICK_METHOD_NONE
    LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS
    LIBINPUT_CONFIG_CLICK_METHOD_CLICKFINGER
    */
    static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;

    /* You can choose between:
    LIBINPUT_CONFIG_SEND_EVENTS_ENABLED
    LIBINPUT_CONFIG_SEND_EVENTS_DISABLED
    LIBINPUT_CONFIG_SEND_EVENTS_DISABLED_ON_EXTERNAL_MOUSE
    */
    static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;

    /* You can choose between:
    LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT
    LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE
    */
    static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
    static const double accel_speed = 0.0;

    /* You can choose between:
    LIBINPUT_CONFIG_TAP_MAP_LRM -- 1/2/3 finger tap maps to left/right/middle
    LIBINPUT_CONFIG_TAP_MAP_LMR -- 1/2/3 finger tap maps to left/middle/right
    */
    static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

    /* If you want to use the windows key for MODKEY, use WLR_MODIFIER_LOGO */
    #define MODKEY WLR_MODIFIER_LOGO

    #define TAGKEYS(KEY,SKEY,TAG) \
      { MODKEY,                    KEY,            view,            {.ui = 1 << TAG} }, \
      { MODKEY|WLR_MODIFIER_CTRL,  KEY,            toggleview,      {.ui = 1 << TAG} }, \
      { MODKEY|WLR_MODIFIER_SHIFT, SKEY,           tag,             {.ui = 1 << TAG} }, \
      { MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT,SKEY,toggletag, {.ui = 1 << TAG} }

    /* helper for spawning shell commands in the pre dwm-5.0 fashion */
    #define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

    /* commands */
    static const char *termcmd[] = { "foot", NULL };
    static const char *menucmd[] = { "fuzzel", NULL };

    /* NOTE: If you use dmenu, prefix it with 'spawn' to have it execute properly */
    static const Key keys[] = {
      /* Note that Shift changes certain key codes: c -> C, 2 -> at, etc. */
      /* modifier                  key                 function        argument */
      { MODKEY,                    XKB_KEY_p,          spawn,          {.v = menucmd} },
      { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return,     spawn,          {.v = termcmd} },
      { MODKEY,                    XKB_KEY_j,          focusstack,     {.i = +1} },
      { MODKEY,                    XKB_KEY_k,          focusstack,     {.i = -1} },
      { MODKEY,                    XKB_KEY_i,          incnmaster,     {.i = +1} },
      { MODKEY,                    XKB_KEY_d,          incnmaster,     {.i = -1} },
      { MODKEY,                    XKB_KEY_h,          setmfact,       {.f = -0.05f} },
      { MODKEY,                    XKB_KEY_l,          setmfact,       {.f = +0.05f} },
      { MODKEY,                    XKB_KEY_Return,     zoom,           {0} },
      { MODKEY,                    XKB_KEY_Tab,        view,           {0} },
      { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_C,          killclient,     {0} },
      { MODKEY,                    XKB_KEY_t,          setlayout,      {.v = &layouts[0]} },
      { MODKEY,                    XKB_KEY_f,          setlayout,      {.v = &layouts[1]} },
      { MODKEY,                    XKB_KEY_m,          setlayout,      {.v = &layouts[2]} },
      { MODKEY,                    XKB_KEY_space,      setlayout,      {0} },
      { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_space,      togglefloating, {0} },
      { MODKEY,                    XKB_KEY_e,          togglefullscreen, {0} },
      { MODKEY,                    XKB_KEY_0,          view,           {.ui = ~0} },
      { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_parenright, tag,            {.ui = ~0} },
      { MODKEY,                    XKB_KEY_comma,      focusmon,       {.i = WLR_DIRECTION_LEFT} },
      { MODKEY,                    XKB_KEY_period,     focusmon,       {.i = WLR_DIRECTION_RIGHT} },
      { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_less,       tagmon,         {.i = WLR_DIRECTION_LEFT} },
      { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_greater,    tagmon,         {.i = WLR_DIRECTION_RIGHT} },
      TAGKEYS(          XKB_KEY_1, XKB_KEY_exclam,                     0),
      TAGKEYS(          XKB_KEY_2, XKB_KEY_at,                         1),
      TAGKEYS(          XKB_KEY_3, XKB_KEY_numbersign,                 2),
      TAGKEYS(          XKB_KEY_4, XKB_KEY_dollar,                     3),
      TAGKEYS(          XKB_KEY_5, XKB_KEY_percent,                    4),
      TAGKEYS(          XKB_KEY_6, XKB_KEY_asciicircum,                5),
      TAGKEYS(          XKB_KEY_7, XKB_KEY_ampersand,                  6),
      TAGKEYS(          XKB_KEY_8, XKB_KEY_asterisk,                   7),
      TAGKEYS(          XKB_KEY_9, XKB_KEY_parenleft,                  8),
      { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Q,          quit,           {0} },
      { MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, XKB_KEY_Q, quit, {1} },
    };

    static const Button buttons[] = {
      { MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
      { MODKEY, BTN_MIDDLE, togglefloating, {0} },
      { MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
    };
  '';

  # Enable required services
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Security
  security.rtkit.enable = true;
  security.polkit.enable = true;

  # Essential environment variables
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";  # Fix cursor issues
    NIXOS_OZONE_WL = "1";           # Enable Wayland for Chrome/Electron
    MOZ_ENABLE_WAYLAND = "1";       # Enable Wayland for Firefox
    QT_QPA_PLATFORM = "wayland";    # Qt applications use Wayland
    GDK_BACKEND = "wayland";        # GTK applications use Wayland
    SDL_VIDEODRIVER = "wayland";    # SDL applications use Wayland
    _JAVA_AWT_WM_NONREPARENTING = "1"; # Fix Java applications
  };

  # Font configuration
  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-emoji
      liberation_ttf
      fira-code-nerdfont
    ];
    
    fontconfig = {
      defaultFonts = {
        monospace = [ "FiraCode Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
      };
    };
  };

  # XDG portals for desktop integration
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
  };

  # Enable hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
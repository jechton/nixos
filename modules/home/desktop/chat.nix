{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
let
  c = config.lib.stylix.colors.withHashtag;
  mono = config.burrow.theme.fonts.monospace.name;

  system24 = /* css */ ''
    /**
     * @name system24
     * @description a tui-style discord theme.
     * @author refact0r
     * @source https://github.com/refact0r/system24
    */

    @import url('https://refact0r.github.io/system24/build/system24.css');

    body {
        /* font, change to ''' for default discord font */
        --font: '${mono}';
        --code-font: '${mono}';
        font-weight: 300; /* text font weight. 300 is light, 400 is normal. does not affect bold text */
        letter-spacing: -0.05ch; /* tighter tracking, recommended on monospace fonts */

        /* sizes */
        --gap: 12px; /* spacing between panels */
        --divider-thickness: 4px; /* thickness of unread messages divider and highlighted message borders */
        --border-thickness: 2px; /* thickness of borders around main panels, does not affect other borders */
        --border-hover-transition: 0.2s ease; /* transition for borders when hovered */

        /* animation/transition options */
        --animations: on; /* off: disable animations/transitions, on: enable */
        --list-item-transition: 0.2s ease; /* transition for list items */
        --dms-icon-svg-transition: 0.4s ease; /* transition for the dms icon */

        /* top bar options */
        --top-bar-height: var(--gap); /* discord default is 36px, old discord is 24px, var(--gap) recommended when button position is titlebar */
        --top-bar-button-position: titlebar; /* off: default position, hide: hide buttons completely, serverlist: move inbox button to server list, titlebar: move inbox button to channel titlebar (will hide title) */
        --top-bar-title-position: off; /* off: default centered position, hide: hide title completely, left: left align title (like old discord) */
        --subtle-top-bar-title: off; /* off: default, on: hide the icon and use subtle text color (like old discord) */

        /* window controls */
        --custom-window-controls: off; /* off: default window controls, on: custom window controls */
        --window-control-size: 14px; /* size of custom window controls */

        /* dms button options */
        --custom-dms-icon: off; /* off: use default discord icon, hide: remove icon entirely, custom: use custom icon */
        --dms-icon-svg-url: url('''); /* icon svg url, must be an svg */
        --dms-icon-svg-size: 90%; /* size of the svg (css mask-size property) */
        --dms-icon-color-before: var(--icon-subtle); /* normal icon color */
        --dms-icon-color-after: var(--white); /* icon color when button is hovered/selected */
        --custom-dms-background: off; /* off: disable, image: background image (set url below), color: custom color/gradient */
        --dms-background-image-url: url('''); /* url of the background image */
        --dms-background-image-size: cover; /* size of the background image (css background-size property) */
        --dms-background-color: linear-gradient(70deg, var(--blue-2), var(--purple-2), var(--red-2)); /* fixed color/gradient (css background property) */

        /* background image options */
        --background-image: off; /* off: no background image, on: enable (set url below) */
        --background-image-url: url('''); /* url of the background image */

        /* transparency/blur options, require transparent bg colors to be visible */
        --transparency-tweaks: off; /* on: remove some elements for better transparency */
        --remove-bg-layer: off; /* on: remove the base --bg-3 layer for window transparency, overrides background image */
        --panel-blur: off; /* on: blur the background of panels */
        --blur-amount: 12px; /* amount of blur */
        --bg-floating: var(--bg-3); /* more opaque color for floating panels if they look too transparent, only applies with panel blur on */

        /* other options */
        --small-user-panel: on; /* on: smaller user panel like old discord */

        /* unrounding options */
        --unrounding: on; /* on: remove rounded corners from panels */
        --round-pfp: off; /* off: square profile pictures, on: rounded (discord default) */
        --remove-pfp-decor: off; /* on: remove profile picture decorations */

        /* styling options */
        --custom-spotify-bar: on; /* on: custom text-like spotify progress bar */
        --ascii-titles: on; /* on: ascii font for channel-start titles */
        --ascii-loader: system24; /* off, system24, or cats */

        /* panel labels */
        --panel-labels: on; /* on: add labels to panels */
        --label-color: var(--text-muted); /* color of labels */
        --label-font-weight: 500; /* font weight of labels */
    }

    /* color options, driven by the stylix base16 palette */
    :root {
        --colors: on; /* off: discord default colors, on: custom colors below */

        /* text colors */
        --text-0: var(--bg-4); /* text on colored elements */
        --text-1: ${c.base07}; /* other normally white text */
        --text-2: ${c.base06}; /* headings and important text */
        --text-3: ${c.base05}; /* normal text */
        --text-4: ${c.base04}; /* icon buttons and channels */
        --text-5: ${c.base03}; /* muted channels/chats and timestamps */

        /* background and dark colors */
        --bg-1: ${c.base02}; /* dark buttons when clicked */
        --bg-2: ${c.base01}; /* dark buttons */
        --bg-3: color-mix(in srgb, ${c.base00} 82%, black); /* recessed gap/void color, spacing and secondary elements */
        --bg-4: ${c.base00}; /* main background color */
        --hover: color-mix(in srgb, ${c.base04} 10%, transparent); /* channels and buttons when hovered */
        --active: color-mix(in srgb, ${c.base04} 18%, transparent); /* channels and buttons when clicked or selected */
        --active-2: color-mix(in srgb, ${c.base04} 26%, transparent); /* extra state for transparent buttons */
        --message-hover: color-mix(in srgb, black 12%, transparent); /* messages when hovered */

        /* accent colors */
        --accent-1: var(--blue-1); /* links and other accent text */
        --accent-2: var(--blue-2); /* small accent elements */
        --accent-3: var(--blue-3); /* accent buttons */
        --accent-4: var(--blue-4); /* accent buttons when hovered */
        --accent-5: var(--blue-5); /* accent buttons when clicked */
        --accent-new: var(--red-2); /* stuff that's normally red like mute/deafen buttons */
        --mention: linear-gradient(to right, color-mix(in hsl, var(--accent-2), transparent 90%) 40%, transparent); /* background of messages that mention you */
        --mention-hover: linear-gradient(to right, color-mix(in hsl, var(--accent-2), transparent 95%) 40%, transparent); /* same, when hovered */
        --reply: linear-gradient(to right, color-mix(in hsl, var(--text-3), transparent 90%) 40%, transparent); /* background of messages that reply to you */
        --reply-hover: linear-gradient(to right, color-mix(in hsl, var(--text-3), transparent 95%) 40%, transparent); /* same, when hovered */

        /* status indicator colors, comments give the discord defaults */
        --online: var(--green-2); /* default #43a25a */
        --dnd: var(--red-2); /* default #d83a42 */
        --idle: var(--yellow-2); /* default #ca9654 */
        --streaming: var(--purple-2); /* default #593695 */
        --offline: var(--text-4); /* default #83838b */

        /* border colors */
        --border-light: var(--hover); /* general light border color */
        --border: var(--active); /* general normal border color */
        --border-hover: var(--accent-2); /* border color of panels when hovered */
        --button-border: color-mix(in srgb, ${c.base06} 10%, transparent); /* neutral border color of buttons */

        /* base color ramps, 1 lightest to 5 darkest (hover/pressed states use the higher numbers) */
        --red-1: color-mix(in srgb, ${c.base08} 88%, white);
        --red-2: ${c.base08};
        --red-3: ${c.base08};
        --red-4: color-mix(in srgb, ${c.base08} 78%, black);
        --red-5: color-mix(in srgb, ${c.base08} 60%, black);

        --green-1: color-mix(in srgb, ${c.base0B} 88%, white);
        --green-2: ${c.base0B};
        --green-3: ${c.base0B};
        --green-4: color-mix(in srgb, ${c.base0B} 78%, black);
        --green-5: color-mix(in srgb, ${c.base0B} 60%, black);

        --blue-1: color-mix(in srgb, ${c.base0D} 88%, white);
        --blue-2: ${c.base0D};
        --blue-3: ${c.base0D};
        --blue-4: color-mix(in srgb, ${c.base0D} 78%, black);
        --blue-5: color-mix(in srgb, ${c.base0D} 60%, black);

        --yellow-1: color-mix(in srgb, ${c.base0A} 88%, white);
        --yellow-2: ${c.base0A};
        --yellow-3: ${c.base0A};
        --yellow-4: color-mix(in srgb, ${c.base0A} 78%, black);
        --yellow-5: color-mix(in srgb, ${c.base0A} 60%, black);

        --purple-1: color-mix(in srgb, ${c.base0E} 88%, white);
        --purple-2: ${c.base0E};
        --purple-3: ${c.base0E};
        --purple-4: color-mix(in srgb, ${c.base0E} 78%, black);
        --purple-5: color-mix(in srgb, ${c.base0E} 60%, black);
    }
  '';
in
{
  imports = [ inputs.nixcord.homeModules.nixcord ];

  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    home.packages = [
      # keep-sorted start
      pkgs.signal-desktop
      pkgs.slack
      pkgs.telegram-desktop
      # keep-sorted end
    ];

    stylix.targets.nixcord.enable = false;

    programs.nixcord = {
      enable = true;
      discord.enable = false;
      equibop = {
        enable = true;
        settings = {
          # keep-sorted start block=yes
          arRPC = true;
          badgeOnlyForMentions = true;
          clickTrayToShowHide = true;
          discordBranch = "stable";
          enableSplashScreen = false;
          minimizeToTray = true;
          # Minimize flashing on startup
          splashBackground = c.base00;
          splashColor = c.base05;
          splashProgress = true;
          splashTheming = true;
          startMinimized = true;
          # keep-sorted end
        };
        state = {
          firstLaunch = false;
        };
      };
      config = {
        themes.system24 = system24;
        enabledThemes = [ "system24.css" ];
      };
      equibopConfig = {
        plugins = {
          # keep-sorted start block=yes
          betterFolders = {
            enable = true;
            sidebar = false;
            closeAllFolders = true;
            closeAllHomeButton = true;
            closeOthers = true;
            forceOpen = true;
          };
          betterGifAltText.enable = true;
          betterGifPicker.enable = true;
          betterInvites.enable = true;
          blurNSFW.enable = true;
          callTimer = {
            enable = true;
            format = "human";
          };
          characterCounter.enable = true;
          clearURLS.enable = true;
          declutter = {
            enable = true;
            alwaysShowUsername = false;
            removeAudioMenus = false;
            removeClanTag = false;
            removeNameplate = false;
            removeProfileEffect = false;
            removeProfileFrame = false;
            removeShopAboveDms = true;
          };
          friendsSince.enable = true;
          fullSearchContext.enable = true;
          gitHubRepos.enable = true;
          greetStickerPicker.enable = true;
          homeTyping.enable = true;
          implicitRelationships.enable = true;
          mentionAvatars.enable = true;
          moreCommands.enable = true;
          musicRichPresence = {
            enable = true;
            nameFormat = "song-first";
            scrobblerBackend = "listenbrainz";
            useListeningStatus = true;
            username = "jechton";
          };
          mutualGroupDMs.enable = true;
          noF1.enable = true;
          noNitroUpsell.enable = true;
          noReplyMention = {
            enable = true;
            inverseShiftReply = true;
          };
          noServerEmojis = {
            enable = true;
            shownEmojis = "currentServer";
          };
          previewMessage.enable = true;
          typingIndicator.enable = true;
          typingTweaks.enable = true;
          viewRaw.enable = true;
          whoReacted.enable = true;
          # keep-sorted end
        };
      };
    };

    home.persistence."/persist".directories = [
      ".config/Signal"
      ".config/Slack"
      ".config/equibop/sessionData"
      ".local/share/TelegramDesktop"
    ];
  };
}

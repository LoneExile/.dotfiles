# The interactive zsh of the agent role (home/linux/agent.nix imports it): the Mac's own files and plugins, on the VM.
#
# What is shared with the Mac, not copied: home/zsh/config/{aliases,options,keybindings}.zsh are sourced from the
# store copy that this flake names, byte for byte (roles-check.sh compares them with the repo files). What is not:
# home/zsh/zshrc is the Mac's (zap is fetched with curl at shell start, `getconf DARWIN_USER_TEMP_DIR`, ~/Library/pnpm,
# kubectl, treehouse and aws completions, atuin); the equivalent for the VM is below, in the same order: the
# three files, then the plugins, then compinit. The plugins come from nixpkgs, so nothing is fetched at shell start.
#
# Only a real terminal gets any of it. A shell without one (omp's shell, `zsh -i` run by a script) takes the early exit
# of the Mac's home/default.nix (order 500) and loads no plugin; `zsh -c` and `zsh -lc` never read ~/.zshrc at all.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.agent.zsh;

  # Freed-Wu/fzf-tab-source (the previews for fzf-tab) is in no nixpkgs (25.11 and unstable: measured), so it is pinned
  # here: the commit and the hash of its source tree. A bump is a new rev and `nix flake prefetch github:Freed-Wu/fzf-tab-source`.
  fzfTabSource = pkgs.fetchFromGitHub {
    owner = "Freed-Wu";
    repo = "fzf-tab-source";
    rev = "3253ab5afa76cadd944a2775eb750321a64f6b8b";
    hash = "sha256-d7+yKrHp4Vcl5WlQfQ/UMNK5j3wz8Ls168Cuj1LYTgI=";
  };
in {
  options.dotfiles.agent.zsh.enable = lib.mkEnableOption "the Mac's aliases, options, keybindings and zsh plugins (nixpkgs) in the interactive zsh of the user, with fzf";

  config = lib.mkIf cfg.enable {
    # fzf-tab calls it.
    home.packages = [pkgs.fzf];

    programs.zsh.initContent = lib.mkMerge [
      (lib.mkOrder 500 ''
        # Not a real terminal (omp's shell, a scripted `zsh -i`): no aliases, no plugins, no prompt, nothing printed.
        # Only mise stays active, as in the Mac's early exit, because the later line of Home Manager that
        # activates it is skipped by the return.
        if [[ ! -t 0 || ! -t 1 ]]; then
          ${lib.optionalString config.dotfiles.agent.mise.enable ''(( $+commands[mise] )) && eval "$(mise activate zsh)" 2>/dev/null''}
          return 2>/dev/null || true
        fi
      '')

      (lib.mkOrder 1000 ''
        # The order of the Mac's home/zsh/zshrc: the three files, the plugins, then compinit.
        source ${../zsh/config/aliases.zsh}
        source ${../zsh/config/options.zsh}
        source ${../zsh/config/keybindings.zsh}

        # options.zsh puts the output of `which nvim` into EDITOR and VISUAL. There is no nvim on this machine, and the
        # output is then the text "nvim not found".
        if (( ! $+commands[nvim] )); then
          export EDITOR=vim VISUAL=vim
        fi

        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
        source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        # As the Mac's plugin manager does for zsh-completions: its completers join the fpath, which compinit reads below.
        fpath+=(${pkgs.zsh-completions}/share/zsh/site-functions)
        source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
        source ${fzfTabSource}/fzf-tab-source.plugin.zsh

        # compinit runs here and nowhere else (programs.zsh.enableGlobalCompInit is off, so that /etc/zshrc does not run
        # it before this file extends the fpath), cached like the Mac's: -C takes the dump as it is, and the full run
        # (with its security audit) happens once a day. The dump is also for one system generation: a deploy changes the
        # packages that have completers, and a dump made before it (even a young one) would not know them.
        _zc_dir=''${XDG_CACHE_HOME:-$HOME/.cache}/zsh
        _zc_key=''${''${:-/run/current-system}:A:t}
        mkdir -p $_zc_dir
        [[ -r $_zc_dir/zcompdump.key ]] && _zc_have=$(<$_zc_dir/zcompdump.key) || _zc_have=
        autoload -Uz compinit
        if [[ $_zc_have != $_zc_key || -n $_zc_dir/zcompdump(#qN.mh+24) ]]; then
          compinit -d $_zc_dir/zcompdump && print -r -- $_zc_key >| $_zc_dir/zcompdump.key
        else
          compinit -C -d $_zc_dir/zcompdump
        fi
        unset _zc_dir _zc_key _zc_have
      '')
    ];
  };
}

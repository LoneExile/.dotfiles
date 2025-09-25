# nixCats Neovim Configuration

This directory contains a comprehensive Neovim configuration built with [nixCats](https://github.com/BirdeeHub/nixCats-nvim), a Nix-based Neovim configuration system that provides modular, reproducible, and extensible editor setups.

## Overview

This configuration provides a fully-featured development environment with:

- **Language Server Protocol (LSP)** support for Lua, Nix, and Go
- **Modern completion** system with blink-cmp
- **Syntax highlighting** with Tree-sitter
- **File navigation** with mini.files
- **Git integration** with gitsigns
- **Status line** with lualine
- **Key mapping discovery** with which-key
- **Debugging support** for Go development

## Directory Structure

```
home/nvim-config/
├── README.md                    # This file
├── init.lua                     # Main configuration entry point
├── lua/
│   ├── config/                  # Core configuration modules
│   │   ├── options.lua          # Editor options and settings
│   │   ├── keymaps.lua          # Key mappings and shortcuts
│   │   └── autocmds.lua         # Automatic commands and events
│   └── plugins/                 # Plugin configurations
│       ├── lsp.lua              # Language server configurations
│       ├── completion.lua       # Completion system setup
│       ├── ui.lua               # UI and navigation plugins
│       └── development.lua      # Development tools (linting, formatting, debugging)
```

## Categories

The configuration is organized into categories that can be enabled or disabled based on your development needs:

### Core Categories

- **`general`**: Essential plugins and tools required for basic functionality
  - Core utilities (ripgrep, fd, tree-sitter)
  - UI components (lualine, mini.files, which-key)
  - Git integration (gitsigns)
  - Completion system (blink-cmp)
  - Syntax highlighting (treesitter)

### Language-Specific Categories

- **`lua`**: Lua development environment
  - Language server: `lua-language-server`
  - Formatter: `stylua`
  - Plugin: `lazydev-nvim` for enhanced Lua development

- **`nix`**: Nix development environment
  - Language server: `nixd`
  - Formatter: `alejandra`

- **`go`**: Go development environment
  - Language server: `gopls`
  - Linter: `golangci-lint`
  - Debugger: `delve`
  - Plugins: `nvim-dap`, `nvim-dap-go`, `nvim-dap-ui`

## Configuration

The nixCats configuration is defined in `home/le.nix` with the following structure:

```nix
nixCats = {
  enable = true;
  addOverlays = [ (inputs.nixCats.utils.standardPluginOverlay inputs) ];
  packageNames = [ "leNvim" ];
  luaPath = ./nvim-config;  # Points to this directory

  categoryDefinitions.replace = {
    # LSPs, formatters, and tools for each category
    lspsAndRuntimeDeps = { ... };
    # Essential plugins loaded at startup
    startupPlugins = { ... };
    # Optional plugins for specific languages
    optionalPlugins = { ... };
  };

  packageDefinitions.replace = {
    leNvim = {
      settings = {
        aliases = [ "vim" "nvim" ];
        # ... other settings
      };
      categories = {
        general = true;
        lua = true;
        nix = true;
        go = true;
      };
    };
  };
};
```

## Usage Instructions

### Basic Usage

Once the configuration is applied through home-manager, you can use Neovim with:

```bash
nvim <file>    # or vim <file> due to aliases
```

### Key Mappings

The configuration includes essential key mappings defined in `lua/config/keymaps.lua`:

- **Leader key**: `<Space>`
- **File navigation**: `<leader>e` - Toggle file explorer
- **Find files**: `<leader>ff` - Fuzzy find files
- **Find text**: `<leader>fg` - Live grep search
- **LSP actions**: `gd` (go to definition), `gr` (references), `K` (hover)
- **Completion**: `<Tab>` and `<S-Tab>` for navigation, `<CR>` to accept

### Language-Specific Features

#### Lua Development
- Automatic LSP setup for `.lua` files
- Code formatting with stylua
- Enhanced development with lazydev-nvim

#### Nix Development
- Automatic LSP setup for `.nix` files
- Code formatting with alejandra
- Syntax highlighting and error detection

#### Go Development
- Automatic LSP setup for `.go` files
- Integrated debugging with delve
- Linting with golangci-lint
- Test running and debugging support

## Customization Guide

### Adding New Languages

To add support for a new language (e.g., Python):

1. **Add the category to `categoryDefinitions`** in `home/le.nix`:
```nix
lspsAndRuntimeDeps = {
  # ... existing categories
  python = [
    python3Packages.python-lsp-server
    black
    isort
  ];
};
```

2. **Enable the category in `packageDefinitions`**:
```nix
categories = {
  # ... existing categories
  python = true;
};
```

3. **Add language-specific configuration** in `lua/plugins/lsp.lua`:
```lua
if nixCats.cats.python then
  lspconfig.pylsp.setup({
    -- Python LSP configuration
  })
end
```

### Modifying Key Mappings

Edit `lua/config/keymaps.lua` to customize key mappings:

```lua
-- Example: Add custom key mapping
vim.keymap.set('n', '<leader>t', ':terminal<CR>', { desc = 'Open terminal' })
```

### Changing Editor Options

Modify `lua/config/options.lua` to adjust editor behavior:

```lua
-- Example: Change tab settings
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
```

### Adding Plugins

To add new plugins:

1. **Add to the appropriate category** in `home/le.nix`:
```nix
startupPlugins = {
  general = [
    # ... existing plugins
    new-plugin-name
  ];
};
```

2. **Configure the plugin** in the appropriate module under `lua/plugins/`:
```lua
-- In lua/plugins/ui.lua, development.lua, etc.
-- Add to the existing require('lze').load { ... } block:
{
  "new-plugin-name",
  enabled = nixCats('general') or false,
  event = "DeferredUIEnter",
  after = function (plugin)
    require('new-plugin').setup({
      -- plugin configuration
    })
  end,
},
```

## Troubleshooting

### Common Issues

1. **LSP not working**
   - Check if the language category is enabled in `categories`
   - Verify the LSP is included in `lspsAndRuntimeDeps`
   - Check `:LspInfo` in Neovim for status

2. **Plugin not loading**
   - Ensure the plugin is in the correct category (startupPlugins vs optionalPlugins)
   - Check for syntax errors in plugin configuration files
   - Use `:checkhealth` in Neovim for diagnostics

3. **Configuration not applying**
   - Run `home-manager switch` to apply changes
   - Check for Nix syntax errors with `nix-instantiate --parse home/le.nix`

### Validation

Use the provided validation script to check your configuration:

```bash
# Run all validation tests
./scripts/validate-nixcats.sh

# Skip the build test for faster validation
./scripts/validate-nixcats.sh --skip-build
```

### Debug Mode

Enable debug mode by setting the environment variable:

```bash
NIXCATS_DEBUG=1 nvim
```

This will show additional information about category loading and plugin initialization.

## Migration Notes

This configuration replaces the previous custom editors module. The migration preserves:

- Editor preferences (line numbers, tab settings, etc.)
- Essential functionality (file navigation, syntax highlighting)
- Development tool integration (lazygit, mise)

### Differences from Previous Setup

- **vim-airline** → **lualine-nvim**: Modern Lua-based status line
- **nerdtree** → **mini.files**: More efficient file navigation
- **Custom vim config** → **Structured Lua modules**: Better organization and maintainability
- **Manual plugin management** → **nixCats categories**: Declarative plugin management

## Performance

The configuration is optimized for performance through:

- **Lazy loading**: Language-specific plugins load only when needed
- **Category-based loading**: Only enabled categories are loaded
- **Efficient plugins**: Modern, well-maintained plugins with good performance
- **Tree-sitter**: Fast syntax highlighting and code analysis

## Contributing

When modifying this configuration:

1. **Test changes** with the validation script
2. **Document new features** in this README
3. **Follow the category structure** for new languages or features
4. **Maintain backward compatibility** when possible

## Resources

- [nixCats Documentation](https://github.com/BirdeeHub/nixCats-nvim)
- [Neovim Documentation](https://neovim.io/doc/)
- [Home Manager Options](https://mipmip.github.io/home-manager-option-search/)
- [Nix Language Reference](https://nixos.org/manual/nix/stable/language/)

## License

This configuration is part of the personal dotfiles repository and follows the same license terms.
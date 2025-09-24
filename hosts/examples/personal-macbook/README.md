# Personal MacBook Example

This example configuration creates a personalized computing environment optimized for daily personal use, entertainment, hobby development, and creative work.

## Overview

**Profile Used**: Personal  
**Target Users**: Personal users, hobbyist developers, students, creative individuals  
**Use Cases**: Personal daily computing, entertainment, hobby projects, learning, creative work

## Features Included

### Entertainment and Media
- **Music and Video**: Spotify, VLC, IINA, Netflix, YouTube Music
- **Gaming**: Steam, Epic Games, Minecraft, Chess.com
- **Media Creation**: GarageBand, iMovie, Audacity, HandBrake
- **Photo Management**: Photos app, Lightroom, Pixelmator Pro

### Creative Tools
- **Design**: Figma, Canva, Sketch, Pixelmator Pro
- **Art**: GIMP, Inkscape, Procreate (iPad app)
- **3D Modeling**: Blender (optional for 3D enthusiasts)
- **Vector Graphics**: Inkscape for scalable graphics

### Personal Productivity
- **Note-Taking**: Obsidian, Notion, Bear for knowledge management
- **Task Management**: Todoist for personal organization
- **Calendar**: Fantastical for enhanced calendar experience
- **Finance**: Mint, YNAB for personal finance management

### Communication and Social
- **Messaging**: Telegram, Signal, WhatsApp, Discord
- **Video Calls**: Zoom for personal video calls
- **Social Gaming**: Discord for gaming communities
- **Secure Communication**: Signal for privacy-focused messaging

### Learning and Development
- **Education**: Anki flashcards, Duolingo, Khan Academy
- **Hobby Development**: Visual Studio Code, GitHub Desktop, Postman
- **Languages**: Node.js, Python for scripting and learning
- **Version Control**: Git for personal projects

### Health and Lifestyle
- **Fitness**: MyFitnessPal for health tracking
- **Wellness**: Headspace for meditation and mindfulness
- **Personal Growth**: Various learning applications

## Customization Guide

### 1. Basic Setup
Replace the placeholder values in `default.nix`:

```nix
# Update these values
networking.hostName = "your-macbook";
networking.computerName = "Your Personal MacBook";

users.users.yourusername = {  # Replace 'user' with your username
  home = "/Users/yourusername";
  description = "Your Full Name";
};

system.primaryUser = "yourusername";
```

### 2. Entertainment Preferences
Customize entertainment applications based on your interests:

```nix
homebrew.casks = [
  # Keep your preferred streaming services
  "spotify"
  "netflix"
  
  # Add your gaming preferences
  "steam"
  "epic-games"
  
  # Add your creative tools
  "figma"
  "canva"
  
  # Remove applications you don't use
  # "chess-com"  # If you don't play chess
];
```

### 3. Creative Workflow
Adjust creative tools based on your interests:

```nix
environment.systemPackages = with pkgs; [
  # For digital art and design
  gimp
  inkscape
  
  # For 3D work (remove if not interested)
  # blender
  
  # For photography
  imagemagick
  
  # For video work
  ffmpeg
];
```

### 4. Personal Interface
Customize the interface for your comfort:

```nix
system.defaults = {
  # Choose your preferred appearance
  NSGlobalDomain = {
    AppleInterfaceStyle = "Dark";  # or "Light"
  };
  
  dock = {
    autohide = false;              # Keep dock visible
    tilesize = 48;                 # Adjust icon size
    magnification = true;          # Visual enhancement
  };
};
```

## Personal Workflows

### Creative Projects
The configuration sets up directories for creative work:
- `~/Creative/Design/` - Design projects and assets
- `~/Creative/Art/` - Digital art and illustrations
- `~/Creative/Music/` - Music projects and samples
- `~/Creative/Video/` - Video projects and footage

### Learning and Development
Organized structure for learning:
- `~/Development/personal/` - Personal coding projects
- `~/Development/learning/` - Learning exercises and tutorials
- `~/Development/experiments/` - Experimental code and prototypes

### Media Organization
Structured media management:
- `~/Pictures/Screenshots/` - System screenshots
- `~/Pictures/Wallpapers/` - Custom wallpapers
- `~/Pictures/Photos/` - Personal photo collection

## Entertainment Setup

### Gaming Configuration
- Steam and Epic Games for game libraries
- Discord for gaming communities and voice chat
- Chess.com for online chess playing
- Minecraft for creative gaming

### Media Consumption
- Multiple streaming services (Spotify, Netflix)
- VLC and IINA for local media playback
- YouTube Music for music discovery
- Plex for personal media server access

### Content Creation
- GarageBand for music creation
- iMovie for video editing
- Audacity for audio editing
- HandBrake for video conversion

## Learning and Development

### Programming Languages
- **JavaScript/Node.js**: For web development and scripting
- **Python**: For automation, data analysis, and learning
- **Git**: For version control of personal projects

### Development Tools
- **Visual Studio Code**: Primary code editor with extensions
- **GitHub Desktop**: GUI for Git operations
- **Postman**: API testing and development

### Learning Resources
- **Anki**: Spaced repetition for learning new concepts
- **Duolingo**: Language learning
- **Khan Academy**: Educational content across subjects

## Personal Productivity

### Note-Taking and Knowledge Management
- **Obsidian**: Linked note-taking with graph view
- **Notion**: All-in-one workspace for projects and notes
- **Bear**: Simple, elegant note-taking

### Task and Time Management
- **Todoist**: Task management with natural language processing
- **Fantastical**: Enhanced calendar with natural language input

### Finance Management
- **Mint**: Automatic expense tracking and budgeting
- **YNAB**: Zero-based budgeting methodology

## Health and Wellness

### Fitness Tracking
- **MyFitnessPal**: Calorie and nutrition tracking
- Integration with Apple Health for comprehensive health data

### Mental Wellness
- **Headspace**: Guided meditation and mindfulness
- Screen time management through built-in controls

## Privacy and Security

### Personal Privacy Settings
- Disabled personalized advertising
- Configured Safari for balanced privacy
- Password management with 1Password or Bitwarden

### Data Protection
- FileVault encryption enabled by default
- Time Machine backups configured
- Secure messaging with Signal

## Customization Ideas

### For Students
```nix
# Add educational tools
homebrew.casks = [
  "notion"           # Note-taking and organization
  "anki"            # Flashcard learning
  "zotero"          # Research management
  "mendeley"        # Academic reference manager
];
```

### For Creative Professionals
```nix
# Enhanced creative suite
homebrew.casks = [
  "adobe-creative-cloud"  # Professional creative tools
  "sketch"               # UI/UX design
  "principle"            # Animation and interaction design
  "zeplin"              # Design handoff
];
```

### For Gamers
```nix
# Gaming-focused additions
homebrew.casks = [
  "discord"              # Gaming communication
  "obs"                  # Streaming software
  "streamlabs-obs"       # Alternative streaming
  "twitch"              # Game streaming platform
];
```

## Troubleshooting

### Common Personal Use Issues

#### Entertainment App Problems
1. **Streaming Issues**: Check internet connection and app updates
2. **Gaming Performance**: Adjust graphics settings and close background apps
3. **Media Playback**: Try alternative players (VLC, IINA) for compatibility

#### Creative Tool Issues
1. **Large File Handling**: Ensure sufficient storage space and RAM
2. **Export Problems**: Check output format compatibility
3. **Performance**: Close unnecessary applications during intensive work

#### Sync and Backup Issues
1. **Cloud Storage**: Verify account credentials and storage limits
2. **Time Machine**: Ensure backup drive has sufficient space
3. **Cross-Device Sync**: Check iCloud settings and network connectivity

### Performance Optimization

#### For Creative Work
- Increase available RAM for large projects
- Use external storage for media files
- Optimize application preferences for performance

#### For Gaming
- Close background applications during gaming
- Adjust system performance settings
- Monitor temperature and fan speeds

## Maintenance Tips

### Daily Habits
- Regular backup of important personal files
- Keep applications updated for security and features
- Organize downloads and desktop files

### Weekly Tasks
- Clear browser cache and temporary files
- Review and organize photo library
- Update creative project backups

### Monthly Tasks
- Review installed applications and remove unused ones
- Check storage usage and clean up large files
- Update system and security settings

## Getting Support

### Community Resources
- Check the main [Troubleshooting Guide](../../../docs/TROUBLESHOOTING.md)
- Review [Module Documentation](../../../docs/MODULES.md)
- Join online communities for specific applications

### Personal Learning
- Explore application tutorials and documentation
- Join creative communities for inspiration and help
- Participate in hobby development forums

## Contributing

When contributing improvements to this personal configuration:
1. Focus on tools and applications useful for personal computing
2. Consider different personal interests (creative, gaming, learning)
3. Maintain balance between features and system performance
4. Document personal workflow optimizations clearly
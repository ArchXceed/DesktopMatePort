# DesktopMatePort
# Forked version for WAY easier installation: https://github.com/os-guy/DesktopMatePort
## Run DesktopMate (steam) on KDE or Hyprland!
DesktopMatePort is a project that enables running DesktopMate, a Steam application, on KDE Plasma or Hyprland window managers. This port provides compatibility for Linux desktop environments where the application may not natively function properly.

## Infos

### Features
- Compatibility with KDE Plasma
- Support for Hyprland compositor
- Workarounds for common issues
- Easy installation process
- Binaries already in the project (but the source code is still avilable)

### Requirements
- KDE Plasma or Hyprland environment
- All the tutorials are for arch-based system. It works also on Kubuntu or Fedora, but it's not tested and documented

## Tutorial:

### Video Tutorial

A video guide for setting up DesktopMatePort is available here:
[Youtube Tutorial](https://youtu.be/cnwzLD0SCX8?si=inZ55eI9Eks67bqi)

### Download

```bash
sudo pacman -S git
git clone https://github.com/ArchXceed/DesktopMatePort
```

### Prequisite for ./setup.sh:
#### Arch-Based distros (your NEED yay):
(yay: [Install YAY](https://github.com/Jguer/yay))
```bash
sudo pacman -S winetricks wine-staging python zenity tk wget wmctrl
yay -S limitcpu
```
#### Debian-Based distros (Not tested!)
```bash
sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/$(lsb_release -cs)/winehq-$(lsb_release -cs).sources
sudo apt update
sudo apt install --install-recommends winehq-staging winetricks python3 cpulimit zenity tk wmctrl
```

### Next step: Follow the yt tutorial

## Contact
If you have any issues, you can contact me via email: lyam.zambaz@edu.vs.ch

## Contribute

Contributions to DesktopMatePort are welcome and appreciated! If you'd like to improve this project, please consider:

- Submitting bug reports with detailed information
- Creating pull requests with code improvements or new features
- Sharing your experience using the port on different distributions
- Documenting additional configurations or solutions

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## AI?

Yes, I used a lot AI for this project. (I'm in 2nd year of apprenticeship, and didn't want to learn C for a single project).

I would say... 70% of the code AI generated, but still a lot of human debugging :)

You can check out my other project! (Which are not almost Vibe coded). EPTNet, 3000, ...

## Message from the author
`Miku!`

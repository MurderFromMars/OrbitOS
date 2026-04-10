/* OrbitOS Calamares Slideshow */

import QtQuick 2.15
import QtQuick.Layouts 1.15

Presentation {
    id: presentation

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 24

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "░▒▓  O R B I T O S  ▓▒░"
                    color: "#17d4e8"
                    font.pixelSize: 32
                    font.bold: true
                    font.family: "monospace"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Arch Linux // KDE Plasma // CachyOS"
                    color: "#8b949e"
                    font.pixelSize: 16
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Installing your system..."
                    color: "#58a6ff"
                    font.pixelSize: 14
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.7

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Gaming Ready"
                    color: "#17d4e8"
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Steam, Lutris, Heroic Launcher, Wine, Proton,\nMangoHud, and GameMode — all pre-installed.\n\nCachyOS gaming meta packages deliver\noptimized performance out of the box."
                    color: "#c9d1d9"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.4
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.7

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "PS4 Plasma Theme"
                    color: "#17d4e8"
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "A custom PlayStation 4 inspired theme\nfor your KDE Plasma desktop.\n\nApplied automatically on first login\nwith video wallpaper and custom effects."
                    color: "#c9d1d9"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.4
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.7

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "CyberXero Toolkit"
                    color: "#17d4e8"
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "A GTK4 system management application\nfor hardware drivers, optimization toggles,\ngaming packages, and system updates.\n\nLaunch from the app menu: xero-toolkit"
                    color: "#c9d1d9"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.4
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20
                width: parent.width * 0.7

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Handheld Support"
                    color: "#17d4e8"
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Steam Deck, ROG Ally, Legion Go,\nGPD Win, OneXPlayer, and more.\n\nHHD for gamepad, gyro, and TDP control.\nBazzite kernel installs on first login."
                    color: "#c9d1d9"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.4
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Almost there..."
                    color: "#17d4e8"
                    font.pixelSize: 28
                    font.bold: true
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Your OrbitOS installation is finishing up.\nYou'll be ready to game in just a moment."
                    color: "#c9d1d9"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.4
                }
            }
        }
    }
}

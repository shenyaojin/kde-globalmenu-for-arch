/*
 * Copyright 2013  Heena Mahour <heena393@gmail.com>
 * Copyright 2013 Sebastian Kügler <sebas@kde.org>
 * Copyright 2016 Kai Uwe Broulik <kde@privat.broulik.de>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.0
import QtGraphicalEffects 1.0
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.4

import org.kde.plasma.plasmoid 2.0
import org.kde.kquickcontrolsaddons 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

import org.kde.private.windowAppMenu 0.1 as AppMenuPrivate

Item {
    id: root

    readonly property bool vertical: plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool view: plasmoid.configuration.compactView
    readonly property bool inEditMode: plasmoid.userConfiguring || latteInEditMode
    readonly property bool menuAvailable: appMenuModel.menuAvailable
    readonly property bool kcmAuthorized: KCMShell.authorize(["style.desktop"]).length > 0

    readonly property bool inFullView: !plasmoid.configuration.compactView && plasmoid.formFactor === PlasmaCore.Types.Horizontal
    readonly property bool inCompactView: !inFullView

    Plasmoid.preferredRepresentation: plasmoid.fullRepresentation
    Plasmoid.status: inFullView ? fullLayout.status : compactLayout.status

    //BEGIN Layout properties
    Layout.fillWidth: inFullView ? true : root.vertical
    Layout.fillHeight: inFullView ? true : !root.vertical
    Layout.minimumWidth: {
        if (inFullView) {
            if (plasmoid.configuration.fillWidth && !inEditMode) {
                return -1;
            }

            return inEditMode ? buttonGrid.width : 0
        } else {
            return -1;
        }
    }

    Layout.preferredWidth: {
        if (inFullView) {
            if (plasmoid.configuration.fillWidth && !inEditMode) {
                return -1;
            }

            return buttonGrid.width;
        } else {
            return Math.max(compactLayout.implicitWidth, root.height);
        }
    }

    Layout.maximumWidth: {
        if (inFullView) {
            return plasmoid.configuration.fillWidth && !inEditMode ? Infinity : buttonGrid.width;
        } else {
            return -1;
        }
    }
    //END Layout properties

    //BEGIN Latte Dock Communicator
    property QtObject latteBridge: null
    onLatteBridgeChanged: {
        if (latteBridge) {
            latteBridge.actions.setProperty(plasmoid.id, "latteSideColoringEnabled", false);
            latteBridge.actions.setProperty(plasmoid.id, "activeIndicatorEnabled", false);
        }
    }

    readonly property bool latteInEditMode: latteBridge && latteBridge.inEditMode
    readonly property bool enforceLattePalette: latteBridge && latteBridge.applyPalette && latteBridge.palette
    //END  Latte Dock Communicator

    onViewChanged: {
        plasmoid.nativeInterface.view = view;
    }

    Component.onCompleted: {
        plasmoid.nativeInterface.buttonGrid = buttonGrid;

        // using a Connections {} doesn't work for some reason in Qt >= 5.8
        plasmoid.nativeInterface.requestActivateIndex.connect(function (index) {
            if(inFullView) {
                var idx = Math.max(0, Math.min(buttonRepeater.count - 1, index))
                var button = buttonRepeater.itemAt(index)

                if (button) {
                    button.clicked()
                }
            } else {
                compactLayout.clicked();
            }
        });

        plasmoid.activated.connect(function () {
            if (inFullView) {
                var button = buttonRepeater.itemAt(0);
                if (button) {
                    button.clicked();
                }
            } else {
                compactLayout.clicked();
            }
        });
    }

    PaintedToolButton {
        id: compactLayout
        anchors.fill: parent
        enabled: menuAvailable
        visible: inCompactView

        buttonIndex: 0
        icon: "application-menu"

        onClicked: {
            if (visible) {
                plasmoid.nativeInterface.trigger(this, buttonIndex);
            }
        }

        readonly property int status: {
            if (menuAvailable && plasmoid.nativeInterface.currentIndex === 0) {
                return PlasmaCore.Types.NeedsAttentionStatus;
            } else if (menuAvailable && appMenuModel.visible){
                return PlasmaCore.Types.ActiveStatus
            } else if (!inEditMode) {
                return PlasmaCore.Types.HiddenStatus;
            }

            return PlasmaCore.Types.PassiveStatus;
        }
    }

    Item {
        id: fullLayout
        anchors.fill: parent
        visible: inFullView

        readonly property int status: {
            if (menuAvailable && plasmoid.nativeInterface.currentIndex > -1 && buttonRepeater.count > 0) {
                return PlasmaCore.Types.NeedsAttentionStatus;
            } else if (menuAvailable){
                //when we're not enabled set to active to show the configure button
                if (buttonRepeater.count > 0) {
                    return PlasmaCore.Types.ActiveStatus
                } else if (!plasmoid.configuration.fillWidth) {
                    return PlasmaCore.Types.HiddenStatus;
                }
            }

            return PlasmaCore.Types.PassiveStatus;
        }

        // So we can show mnemonic underlines only while Alt is pressed
        PlasmaCore.DataSource {
            id: keystateSource
            engine: "keystate"
            connectedSources: ["Alt"]
        }

        MenuFlickable{
            id: gridFlickable
            width: parent.width < contentWidth && !inEditMode ? parent.width : contentWidth
            height: parent.height
            contentWidth: buttonGrid.width
            contentHeight: buttonGrid.height

            GridLayout{
                id: buttonGrid

                flow: GridLayout.LeftToRight
                rowSpacing: 0
                columnSpacing: 0

                Repeater {
                    id: buttonRepeater
                    model: {
                        if (appMenuModel.visible && appMenuModel.menuAvailable) {
                            return appMenuModel;
                        } else if (inEditMode) {
                            return editModeModel;
                        }

                        return null;
                    }

                    PaintedToolButton{
                        id:menuItem

                        Layout.minimumWidth: implicitWidth
                        Layout.preferredWidth: Layout.minimumWidth

                        Layout.minimumHeight: fullLayout.height
                        Layout.preferredHeight: Layout.minimumHeight

                        visible: activeMenu !== ""

                        buttonIndex: index
                        text: activeMenu

                        onClicked: {
                            plasmoid.nativeInterface.trigger(this, index);
                        }

                        onScrolledUp: {
                            if (gridFlickable.contentsExceed) {
                                gridFlickable.increaseX(step);
                            }
                        }

                        onScrolledDown: {
                            if (gridFlickable.contentsExceed) {
                                gridFlickable.decreaseX(step);
                            }
                        }
                    }
                }
            }
        } //end of flickable

        FlickableIndicators{
            anchors.fill: parent

            leftIndicatorOpacity: gridFlickable.contentX / gridFlickable.contentsExtraSpace;
            rightIndicatorOpacity: (gridFlickable.contentsExtraSpace - gridFlickable.contentX) / gridFlickable.contentsExtraSpace
        }
    }

    AppMenuPrivate.AppMenuModel {
        id: appMenuModel

        filterByActive: plasmoid.configuration.filterByActive
        filterChildren: plasmoid.configuration.filterChildrenWindows
        screenGeometry: plasmoid.configuration.filterByScreen ? plasmoid.screenGeometry : Qt.rect(-1, -1, 0, 0) //null geometry
        onRequestActivateIndex: plasmoid.nativeInterface.requestActivateIndex(index)
        Component.onCompleted: {
            plasmoid.nativeInterface.model = appMenuModel
        }
    }


    //! Example model in order to be used in edit mode when there is no
    //! other menu available
    ListModel {
        id: editModeModel

        ListElement {
            activeMenu: "File"
        }
        ListElement {
            activeMenu: "Edit"
        }
        ListElement {
            activeMenu: "Help"
        }
    }
}

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    // SDDM ignores width/height and resizes to the screen; these are
    // a baseline only so the layout renders sanely in qmlscene.
    width: 1920
    height: 1080
    color: "#1e1e2e"

    // The username we currently consider "selected". Either the clicked
    // entry in userList or whatever was typed into manualUsername.
    // sessionsModel is filtered whenever this changes.
    property string currentUser: ""

    // Filtered session entries derived from sessionModel + theme.conf.
    // Each item: { name: string, originalIndex: int } where
    // originalIndex is the index into the unfiltered sessionModel so
    // sddm.login() still receives the right session selector.
    property var filteredSessions: []

    function rebuildFilter() {
        // theme.conf carries one key per user: sessions_<username> with
        // a semicolon-separated list of session basenames (without
        // `.desktop`). An empty/missing value means "show everything",
        // which is the safe fallback for new accounts the host config
        // hasn't yet enumerated.
        var allowed = null;
        if (currentUser && currentUser.length > 0) {
            var raw = config.stringValue("sessions_" + currentUser);
            if (raw && raw.length > 0) {
                allowed = raw.split(";").filter(function (s) { return s.length > 0; });
            }
        }

        var result = [];
        for (var i = 0; i < sessionAccessor.count; i++) {
            var item = sessionAccessor.itemAt(i);
            if (!item) continue;
            var basename = item.sessFile.replace(/\.desktop$/, "");
            if (allowed === null || allowed.indexOf(basename) !== -1) {
                result.push({ name: item.sessName, originalIndex: i });
            }
        }
        filteredSessions = result;
        sessionCombo.currentIndex = 0;
    }

    onCurrentUserChanged: rebuildFilter()

    // sessionModel/userModel are QAbstractListModels exposed by SDDM.
    // QML can't read their role data by index directly, so a hidden
    // Repeater instantiates one Item per row that surfaces the roles
    // as plain properties — rebuildFilter() walks `sessionAccessor`
    // instead of poking at sessionModel.data() through role IDs.
    Repeater {
        id: sessionAccessor
        model: sessionModel
        delegate: Item {
            visible: false
            required property string name
            required property string file
            property string sessName: name
            property string sessFile: file
        }
        onCountChanged: root.rebuildFilter()
    }

    Component.onCompleted: {
        if (userModel.lastIndex >= 0 && userModel.lastIndex < userModel.count) {
            userList.currentIndex = userModel.lastIndex;
        } else if (userModel.count > 0) {
            userList.currentIndex = 0;
        }
        rebuildFilter();
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: 360

        Label {
            Layout.fillWidth: true
            text: Qt.formatDateTime(new Date(), "dddd, MMMM d  •  h:mm AP")
            color: "#cdd6f4"
            font.pointSize: 14
            horizontalAlignment: Text.AlignHCenter
        }

        ListView {
            id: userList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(36, Math.min(userModel.count, 5) * 40)
            model: userModel
            currentIndex: -1
            clip: true
            visible: userModel.count > 0

            delegate: ItemDelegate {
                required property int index
                required property string name
                required property string realName
                width: ListView.view.width
                text: realName && realName.length > 0 ? realName : name
                highlighted: ListView.isCurrentItem
                onClicked: {
                    userList.currentIndex = index;
                    root.currentUser = name;
                    passwordField.forceActiveFocus();
                }
            }
        }

        // Fallback path: if userModel is empty (e.g. HideUsers config),
        // accept a typed username. Also kept available for users that
        // exist on the system but aren't surfaced in the list.
        TextField {
            id: manualUsername
            Layout.fillWidth: true
            placeholderText: "Username"
            visible: userModel.count === 0
            onTextChanged: if (visible) root.currentUser = text
        }

        TextField {
            id: passwordField
            Layout.fillWidth: true
            placeholderText: "Password"
            echoMode: TextInput.Password
            Keys.onReturnPressed: loginBtn.clicked()
            Keys.onEnterPressed: loginBtn.clicked()
        }

        ComboBox {
            id: sessionCombo
            Layout.fillWidth: true
            model: root.filteredSessions
            textRole: "name"
            enabled: root.filteredSessions.length > 1
        }

        Label {
            id: errorLabel
            Layout.fillWidth: true
            color: "#f38ba8"
            wrapMode: Text.Wrap
            visible: text.length > 0
        }

        Button {
            id: loginBtn
            Layout.fillWidth: true
            text: "Log In"
            enabled: root.filteredSessions.length > 0 && root.currentUser.length > 0
            onClicked: {
                errorLabel.text = "";
                if (root.filteredSessions.length === 0) {
                    errorLabel.text = "No sessions available for " + root.currentUser;
                    return;
                }
                var entry = root.filteredSessions[sessionCombo.currentIndex];
                sddm.login(root.currentUser, passwordField.text, entry.originalIndex);
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Button {
                Layout.fillWidth: true
                text: "Reboot"
                enabled: sddm.canReboot
                onClicked: sddm.reboot()
            }
            Button {
                Layout.fillWidth: true
                text: "Shut Down"
                enabled: sddm.canPowerOff
                onClicked: sddm.powerOff()
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorLabel.text = "Login failed";
            passwordField.text = "";
            passwordField.forceActiveFocus();
        }
        function onLoginSucceeded() {
            errorLabel.text = "";
        }
        function onInformationMessage(msg) {
            errorLabel.text = msg;
        }
    }
}

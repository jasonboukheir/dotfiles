# brutus is a zmx host: sessions live here and clients reconnect, so the stable
# agent socket (not sshd's per-connection one) is what zmx shells must see.
{...}: {
  services.ssh-agent-switcher.users = ["jasonbk"];
}

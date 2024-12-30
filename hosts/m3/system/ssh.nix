{ ... }:
{
  # ssh_known_hosts is managed by Chef.
  environment.etc."ssh/ssh_known_hosts".enable = false;
}

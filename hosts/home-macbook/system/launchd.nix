{...}: let
  softLimit = 8192;
  hardLimit = 524288;
in {
  launchd.daemons.limit-maxfiles.serviceConfig = {
    Label = "limit.maxfiles";
    ProgramArguments = ["/bin/launchctl" "limit" "maxfiles" (toString softLimit) (toString hardLimit)];
    RunAtLoad = true;
  };
}

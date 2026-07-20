{ osConfig, ... }: {
  config = {
    burrow.profiles = {
      inherit (osConfig.burrow.profiles) laptop;
    };
  };
}

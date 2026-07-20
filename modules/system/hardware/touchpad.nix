{
  services.libinput = {
    enable = true;
    mouse = {
      accelProfile = "flat";
      accelSpeed = "0";
    };
    touchpad = {
      naturalScrolling = true;
      tapping = true;
      clickMethod = "clickfinger";
      disableWhileTyping = true;
    };
  };
}

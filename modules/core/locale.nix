# Localization: timezone + locale.
#
# Keep timezone and locale together — they're both "where in the
# world is this machine" settings, and both feed glibc locale
# generation (defaultLocale=en_CA.UTF-8 pulls the Canadian locale
# into glibc-locales).
{ config, pkgs, lib, ... }:

{
  # Primary time zone
  time.timeZone = "America/Toronto";

  # Internationalisation / locale properties
  i18n.defaultLocale = "en_CA.UTF-8";
}

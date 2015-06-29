use strict;
use warnings;
use utf8;
use Path::Tiny;
use JSON::PS;

my $root_path = path (__FILE__)->parent->parent;

my $Data = {};

my $sections = {
  できごと => 'historicals',
  日本の自治体改編 => 'jp_towns',
  フィクションのできごと => 'fictionals',
  '記念日・年中行事' => 'memorials',
  誕生日 => 'birthdays',
  忌日 => 'deathdays',
  '誕生日(フィクション)' => 'fictional_birthdays',
};

for (glob $root_path->child ('local/input/*.json')) {
  my $input_path = path ($_);
  my $data = json_bytes2perl $input_path->slurp;
  for my $day_key (keys %$data) {
    $day_key =~ /^([0-9]+)月([0-9]+)日$/ or next;
    my $day = sprintf '%02d-%02d', $1, $2;
    for my $section_key (keys %$sections) {
      my $dest_section_key = $sections->{$section_key};
      for my $section (@{$data->{$day_key}->{lists}->{$section_key} or []}) {
        for my $item (@{$section->{items} or []}) {
          if (ref $item eq 'HASH') {
            push @{$Data->{$day}->{$dest_section_key} ||= []}, $item;
          } else {
            push @{$Data->{_errors} ||= []}, [$day_key, $section_key, $item];
          }
        }
      }
    }
  }
}

print perl2json_bytes_for_record $Data;

## License: Public Domain.

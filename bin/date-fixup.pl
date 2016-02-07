use strict;
use warnings;
use utf8;
use Path::Tiny;
use JSON::PS;
use Kyuureki;
use Web::DateTime::Parser;

my $root_path = path (__FILE__)->parent->parent;

my $eras_path = $root_path->child ('local/era-defs.json');
my $eras = json_bytes2perl $eras_path->slurp;

my $Data = {};

my @out;

sub read_data ($) {
  my $json = shift;

for my $md (sort { $a cmp $b } keys %$json) {
  if ($md eq '_errors') {
    push @{$Data->{_errors} ||= []}, @{$json->{$md}};
    next;
  }
  for my $key (sort { $a cmp $b } keys %{$json->{$md}}) {
    for my $data (@{$json->{$md}->{$key}}) {
      unless (defined $data->{year}) {
        push @{$Data->{$md}->{$key} ||= []}, $data;
        next;
      }

      my ($m, $d) = split /-/, $md;
      my $wp_ad_date = sprintf '%04d-%02d-%02d', $data->{year}, $m, $d;
      my $parser = Web::DateTime::Parser->new;
      my $dt = $parser->parse_julian_ymd_string ($wp_ad_date);
      my $ad_j2g_date = $dt->to_ymd_string;
      my $ad_j2g_md = sprintf '%02d-%02d', $dt->month, $dt->day;

      if (defined $data->{local_date} and
          $data->{local_date} =~ /^戸籍上は/) {
        $data->{desc} .= ' (' . (delete $data->{local_date}) . ')';
      }

      my $wp_local_date = $data->{local_date};
      my $local_ad_date;
      my $local_k2g_date;
      if (defined $wp_local_date) {
        if ($wp_local_date =~ /^(\w+?)(\d+|元)[年載歳](閏|)(\d+)月(\d+)日$/) {
          my ($g, $y, $l, $m, $d) = ($1, $2, $3, $4, $5);
          my $key = $eras->{name_to_key}->{jp}->{$g};
          unless (defined $key) {
            push @{$Data->{_errors} ||= []},
                "LDPARSE: Era name |$g| not defined ($wp_local_date)";
            next;
          }
          my $def = $eras->{eras}->{$key};
          die "Era key |$g| not defined" unless defined $def;
          unless (defined $def->{offset}) {
            push @{$Data->{_errors} ||= []},
                "LDPARSE: Era |$g| has no defined offset ($wp_local_date)";
            next;
          }
          $y = 1 if $y eq '元';
          $local_ad_date = sprintf '%04d-%02d%s-%02d',
              $y + $def->{offset}, $m, $l ? "'" : '', $d;
          my ($g_y, $g_m, $g_d) = kyuureki_to_gregorian $y + $def->{offset}, $m, $l, $d;
          $local_k2g_date = sprintf '%04d-%02d-%02d', $g_y, $g_m, $g_d;
        } elsif ($wp_local_date =~ m{^(\w+?)(\d+|元)[年載歳]/(\w+?)(\d+|元)[年載歳](閏|)(\d+)月(\d+)日$}) {
          my ($g, $y, $g2, $y2, $l, $m, $d) = ($1, $2, $3, $4, $5, $6, $7);

          my $key = $eras->{name_to_key}->{jp}->{$g};
          unless (defined $key) {
            push @{$Data->{_errors} ||= []},
                "LDPARSE: Era name |$g| not defined ($wp_local_date)";
            next;
          }
          my $def = $eras->{eras}->{$key};
          die "Era key |$g| not defined" unless defined $def;
          unless (defined $def->{offset}) {
            push @{$Data->{_errors} ||= []},
                "LDPARSE: Era |$g| has no defined offset ($wp_local_date)";
            next;
          }
          $y = 1 if $y eq '元';
          my $ad = $y + $def->{offset};

          my $key2 = $eras->{name_to_key}->{jp}->{$g2};
          unless (defined $key2) {
            push @{$Data->{_errors} ||= []},
                "LDPARSE: Era name |$g2| not defined ($wp_local_date)";
            next;
          }
          my $def2 = $eras->{eras}->{$key2};
          die "Era key |$g2| not defined" unless defined $def2;
          unless (defined $def2->{offset}) {
            push @{$Data->{_errors} ||= []},
                "LDPARSE: Era |$g2| has no defined offset ($wp_local_date)";
            next;
          }
          $y2 = 1 if $y2 eq '元';
          my $ad2 = $y2 + $def2->{offset};

          unless ($ad == $ad2) {
            push @{$Data->{_errors} ||= []},
                "LDPARSE: $g$y ($ad) != $g2$y2 ($ad2) ($wp_local_date)";
            next;
          }

          $local_ad_date = sprintf '%04d-%02d%s-%02d',
              $ad, $m, $l ? "'" : '', $d;
          my ($g_y, $g_m, $g_d) = kyuureki_to_gregorian $ad, $m, $l, $d;
          $local_k2g_date = sprintf '%04d-%02d-%02d', $g_y, $g_m, $g_d;
        } else {
          push @{$Data->{_errors} ||= []},
              "LDPARSE: Local date |$wp_local_date| not parsable ($wp_local_date)";
        }
      }

      my $md_key = $md;
      if (defined $local_k2g_date) {
        my $wp_ad_type;
        if ($wp_ad_date eq $local_k2g_date) {
          $wp_ad_type = 'g';
          $data->{date_gregorian} = $wp_ad_date;
          $data->{date_kyuureki} = $local_ad_date;
        } elsif ($ad_j2g_date eq $local_k2g_date) {
          $wp_ad_type = 'j';
          $data->{date_julian} = $wp_ad_date;
          $data->{date_gregorian} = $ad_j2g_date;
          $data->{date_kyuureki} = $local_ad_date;
          $md_key = $ad_j2g_md;
        } else {
          $wp_ad_type = '???';
        }
        #push @out, "$wp_ad_date ($wp_ad_type)\tj2g:$ad_j2g_date\tg:$local_k2g_date\tk:$local_ad_date\t$wp_local_date\n";
      } else {
        if ($data->{year} < 1582 or
            ($data->{year} == 1582 and $m < 10) or
            ($data->{year} == 1582 and $m == 10 and $d < 15)) {
          $data->{date_julian} = $wp_ad_date;
          $data->{date_gregorian} = $ad_j2g_date;
          $md_key = $ad_j2g_md;
        } else {
          $data->{date_gregorian} = $wp_ad_date;
        }
      }
      $data->{date_wikipedia} = $wp_ad_date;
      delete $data->{year};
      if (defined $data->{local_date}) {
        $data->{date_wikipedia_local} = delete $data->{local_date};
      }

      push @{$Data->{$md_key}->{$key} ||= []}, $data;
    }
  }
}
} # read_data

for (1..12) {
  my $path = $root_path->child ("local/days-ja-$_.json");
  my $json = json_bytes2perl $path->slurp;
  read_data $json;
}

print perl2json_bytes_for_record $Data;

#binmode STDOUT, q(:encoding(utf-8));
#print $_ for sort { $a cmp $b } @out;

## License: Public Domain.

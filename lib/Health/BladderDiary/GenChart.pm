package Health::BladderDiary::GenChart;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(gen_bladder_chart_from_entries);

use Hash::Subset qw(hash_subset);
use Health::BladderDiary::GenTable;

our %SPEC;

my $gbdt_meta = $Health::BladderDiary::GenTable::SPEC{gen_bladder_diary_table_from_entries};

$SPEC{gen_bladder_diary_chart_from_entries} = {
    v => 1.1,
    summary => 'Create bladder chart from bladder diary entries',
    args => {
        %{ $gdbt_meta->{args} },
        date => {
            schema => 'date*',
            req => 1,
            'x.perl.coerce_to' => 'DateTime',
        },
    },
};
sub gen_bladder_diary_chart_from_entries {
    require Chart::Gnuplot;
    require File::Temp;
    require List::Util;
    require Math::Round;

    my %args = @_;

    my $res = Health::BladderDiary::GenTable::gen_bladder_diary_table_from_entries(
        hash_subset(\%args, $gdbt_meta->{args}),
        _raw => 1,
    );
    use DD; dd $res;

    my ($tempfh, $tempfilename) = File::Temp::tempfile();
    $tempfilename .= ".png";
    my $chart = Chart::Gnuplot->new(
        output   => $tempfilename,
        #title    => 'Urine output on '.($args{date}->ymd),
        xlabel   => 'time',
        ylabel   => 'ml/h',
        timeaxis => 'x',
        timefmt  => '%Y-%m-%dT%H:%M',
    );
    my (@x, @y);
    #
    my $dataset = Chart::Gnuplot::DataSet->new(
        xdata => \@x,
        ydata => \@y,
        title => 'Urine output (ml/h)',
        color => 'red',
        style => 'linespoints',
    );
}

1;
# ABSTRACT: Create bladder diary table from entries

=head1 SYNOPSIS

Your bladder entries e.g. in `bd-entry1.txt` (I usually write in Org document):

 0730 drink: 300ml type=water

 0718 urinate: 250ml

 0758 urinate: 100ml

 0915 drink 300ml

 1230 drink: 600ml, note=thirsty

 1245 urinate: 200ml

From the command-line (I usually run the script from inside Emacs):

 % gen-bladder-diary-table-from-entries < bd-entry1.txt
 | time     | intake type | itime | ivol (ml) | ivol cum | icomment | urination time | uvol (ml) | uvol cum | urgency (0-3) | ucolor (0-3) | ucomment |
 |----------+-------------+-------+-----------+----------+----------+----------------+-----------+----------+---------------+--------------+----------+
 | 07-08.00 | water       | 07.30 |       300 |      300 |          |          07.18 |       250 |      250 |               |              |          |
 |          |             |       |           |          |          |          07.58 |       100 |      350 |               |              |          |
 | 08-09.00 |             |       |           |          |          |                |           |          |               |              |          |
 | 09-10.00 | water       | 09.15 |       300 |      600 |          |                |           |          |               |              |          |
 | 10-11.00 |             |       |           |          |          |                |           |          |               |              |          |
 | 12-13.00 | water       | 12.30 |       600 |     1200 | thirsty  |          12.45 |       200 |          |               |              |          |
 |          |             |       |           |          |          |                |           |          |               |              |          |
 | total    |             |       |      1200 |          |          |                |       550 |          |               |              |          |
 | freq     |             |       |         3 |          |          |                |         3 |          |               |              |          |
 | avg      |             |       |       400 |          |          |                |       183 |          |               |              |          |

Produce CSV instead:

 % gen-bladder-diary-table-from-entries --format csv < bd-entry1.txt > bd-entry1.csv


=head1 DESCRIPTION

This module can be used to visualize bladder diary entries (which is more
comfortable to type in) into table form (which is more comfortable to look at).

=head2 Diary entries

The input to the module is bladder diary entries in the form of text. The
entries should be written in paragraphs, chronologically, each separated by a
blank line. If there is no blank line, then entries are assumed to be written in
single lines.

The format of an entry is:

 <TIME> ("-" <TIME2>)? WS EVENT (":")? WS EXTRA

It is designed to be easy to write. Time can be written as C<hh:mm> or just
C<hhmm> in 24h format.

Event can be one of C<drink> (or C<d> for short), C<eat>, C<urinate> (or C<u> or
C<urin> for short), C<poop>, or C<comment> (or C<c> for short).

Extra is a free-form text, but you can use C<word>=C<text> syntax to write
key-value pairs. Some recognized keys are: C<vol>, C<comment>, C<type>,
C<urgency>, C<color>.

Some other information are scraped for writing convenience:

 /\b(\d+)ml\b/          for volume
 /\bv(\d+)\b/           for volume
 /\bu([0-9]|10)\b/      for urgency (1-10)
 /\bc([0-6])\b/         for clear to dark orange color (0=clear, 1=light yellow, 2=yellow, 3=dark yellow, 4=amber, 5=brown, 6=red)

Example C<drink> entry (all are equivalent):

 07:30 drink: vol=300ml
 0730 drink 300ml
 0730 d 300ml

Example C<urinate> entry (all are equivalent):

 07:45 urinate: vol=200ml urgency=4 color=light yellow comment=at home
 0745 urin 200ml urgency=4 color=light yellow comment=at home
 0745 u 200ml u4 c1 comment=at home

=head3 Urination entries

A urination entry is an entry with event C<urination> (can be written as just
C<u> or C<urin>). At least volume is required, can be written in ml unit e.g.
C<300ml>, or using C<vNUMBER> e.g. C<v300>, or using C<vol> key, e.g.
C<vol=300>. Example:

 1230 u 200ml

You can also enter color, using C<color=NAME> or C<c0>..C<c6> for short. These
colors from 7-color-in-test-tube urine color chart is recommended:
L<https://www.dreamstime.com/urine-color-chart-test-tubes-medical-vector-illustration-image163017644>
or
L<https://stock.adobe.com/images/urine-color-chart-urine-in-test-tubes-medical-vector/299230365>:

 0 - clear
 1 - light yellow
 2 - yellow
 3 - dark yellow
 4 - amber
 5 - brown
 6 - red

Example:

 1230 u 200ml c2

You can also enter urgency information using C<urgency=NUMBER> or C<u0>..C<u10>,
which is a number from 0 (not urgent at all) to 10 (most urgent). Example:

 1230 u 200ml c2 u4

=head2 Drink (fluid intake) entries

A drink (fluid intake) entry is an entry with event C<drink> (can be written as
just C<d>). At least volume is required, can be written in ml unit e.g.
C<300ml>, or using C<vNUMBER> e.g. C<v300>, or using C<vol> key, e.g.
C<vol=300>. Example:

 1300 d 300ml

You can also input the kind of drink using C<type=NAME>. If type is not
specified, C<water> is assumed. Example:

 1300 d 300ml type=coffee

=head2 Eat (food intake) entries

The diary can also contain food intake entries. Currently volume or weight of
food (or volume of fluid, by percentage of food volume) is not measured or
displayed. You can put comments here for more detailed information. The table
generator will create a row for each food intake, but will just display the
time, type ("food"), and comment columns.


=head1 KEYWORDS

voiding diary, bladder diary


=head1 SEE ALSO

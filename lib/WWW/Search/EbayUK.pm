# EbayUK.pm
# Original by Martin Thurn Adapted by Andy Pritchard
# $Id: EbayUK.pm,v 1.00 2003-02-21 17:44:09-05 kingpin Exp kingpin $

=head1 NAME

WWW::Search::EbayUK - backend for searching www.ebay.co.uk

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('EbayUK');
  my $sQuery = WWW::Search::escape_query("Bovine Spongiform Encephalitis");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class is a Ebay specialization of WWW::Search.
It handles making and interpreting Ebay searches
F<http://www.ebay.co.uk>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

=head1 NOTES

The search is done against CURRENT running auctions only.

The query is applied to TITLES only.

The results are ordered youngest auctions first (reverse order of
auction listing date).

In the resulting WWW::Search::Result objects, the description field
consists of a human-readable combination (joined with semicolon-space)
of the Item Number; number of bids; and high bid amount (or starting
bid amount).

=head1 OPTIONS

=over

=item Search descriptions

To search titles and descriptions, add 'srchdesc' => 'y' to the query options:

  $oSearch->native_query($sQuery, { srchdesc => 'y' } );

=back

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 CAVEATS

=head1 BUGS

Please tell the author if you find any!

=head1 AUTHOR

C<WWW::Search::EbayUK> was Adapted by Andy Pritchard from Martin Thurn's Ebay backend
(pilchkinstein@hotmail.com).

C<WWW::Search::Ebay> was written by Martin Thurn
(mthurn@megapipe.net).

C<WWW::Search::Ebay> is maintained by Martin Thurn
(mthurn@megapipe.net).

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

=head2 1.00, 2003-02-14

Adapted Ebay module for ebay.co.uk site

=head2 2.13, 2003-02-06

Fixed parsing for slightly-changed ebay.com pages

=head2 2.11, 2002-10-21

Fixed parsing for Buy-It-Now prices, and foreign currencies

=head2 2.08, 2002-07-24

Fixed parsing for new images in the results table

=head2 2.07, 2001-12-20

Restructured using parse_tree()

=head2 2.06, 2001-12-20

Handle new ebay.com output format

=head2 2.01

First publicly-released version.

=cut

#####################################################################

package WWW::Search::EbayUK;

@ISA = qw( WWW::Search );

use Carp ();
use Data::Dumper;  # for debugging only
use WWW::Search qw( generic_option strip_tags );
use WWW::Search::Result;

$VERSION = '1.00';
$MAINTAINER = 'Andy Pritchard <pilchkinstein@hotmail.com>';

# private
sub native_setup_search
  {
  my ($self, $native_query, $rhOptsArg) = @_;

  # Set some private variables:
  $self->{_debug} ||= $rhOptsArg->{'search_debug'};
  $self->{_debug} = 2 if ($rhOptsArg->{'search_parse_debug'});
  $self->{_debug} ||= 0;

  my $DEFAULT_HITS_PER_PAGE = 50;
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  $self->user_agent('non-robot');

  $self->{'_next_to_retrieve'} = 0;
  $self->{'_num_hits'} = 0;

  if (!defined($self->{_options}))
    {
    $self->{_options} = {
                         'search_url' => 'http://search.ebay.co.uk/search/search.dll',
                         'MfcISAPICommand' => 'GetResult',
                         'ht' => 1,
                         # Default sort order is reverse-order of listing date:
                         'SortProperty' => 'MetaNewSort',
                         'query' => $native_query,
                        };
    } # if
  if (defined($rhOptsArg))
    {
    # Copy in new options.
    foreach my $key (keys %$rhOptsArg)
      {
      # print STDERR " +   inspecting option $key...";
      if (WWW::Search::generic_option($key))
        {
        # print STDERR "promote & delete\n";
        $self->{$key} = $rhOptsArg->{$key} if defined($rhOptsArg->{$key});
        delete $rhOptsArg->{$key};
        }
      else
        {
        # print STDERR "copy\n";
        $self->{_options}->{$key} = $rhOptsArg->{$key} if defined($rhOptsArg->{$key});
        }
      } # foreach
    } # if

  # Finally, figure out the url.
  $self->{_next_url} = $self->{_options}->{'search_url'} .'?'. $self->hash_to_cgi_string($self->{_options});
  } # native_setup_search


sub preprocess_results_page
  {
  my $self = shift;
  my $sPage = shift;
  # Ebay sends malformed HTML:
  my $iSubs = 0 + ($sPage =~ s!</FONT></TD></FONT></TD>!</FONT></TD>!gi);
  print STDERR " +   deleted $iSubs extraneous tags\n" if 1 < $self->{_debug};
  print STDERR " + RawHTML ===>$sPage<=== RawHTML\n" if 2 < $self->{_debug};
  return $sPage;
  } # preprocess_results_page


# private
sub parse_tree
  {
  my $self = shift;
  my $tree = shift;

  # A pattern to match HTML whitespace:
  my $W = q{[\ \t\r\n\240]};
  # A pattern to match Ebay currencies:
  my $currency = qr/(?:\$|C|EUR|GBP|\£)/;
  my $hits_found = 0;
  if (2 < $self->{_debug}) {
  	print STDERR "=========================== HTML::Tree Dump START ============================\n";
  	print STDERR $tree->as_HTML();
  	print STDERR "============================ HTML::Tree Dump END =============================\n";
  }
  # The hit count is in a FONT tag:
  my @aoFONT = $tree->look_down('_tag', 'font');
 FONT:
  foreach my $oFONT (@aoFONT)
    {
    print STDERR " +   try FONT ===", $oFONT->as_text, "===\n" if 1 < $self->{_debug};
    if ($oFONT->as_text =~ m!(\d+) items found !)
      {
      $self->approximate_result_count($1);
      last FONT;
      } # if
    } # foreach
  # The list of matching items is in a table.  The first column of the
  # table is nothing but icons; the second column is the good stuff.
  my @aoTD = $tree->look_down('_tag', 'td',
                              sub { (
                                     ($_[0]->as_HTML =~ m!ViewItem! )
                                     &&
                                     # Ignore thumbnails:
                                     ($_[0]->as_HTML !~ m!thumbs\.ebay\.com! ) # We need to ignore .com
                                     &&
                                     ($_[0]->as_HTML !~ m!thumbs\.ebay\.co\.uk! ) # and .co.uk
                                     &&
                                     # Ignore other images:
                                     ($_[0]->as_HTML !~ m/alt="\[Picture!\]"/i )
                                     &&
                                     ($_[0]->as_HTML !~ m!alt="BuyItNow"!i )
                                    )
                                  }
                             );
 TD:
  foreach my $oTD (@aoTD)
    {
    my $sTD = $oTD->as_HTML;
    # First FONT tag contains the url & title:
    my $oFONT = $oTD->look_down('_tag', 'font');
    next TD unless ref $oFONT;
    # First A tag contains the url & title:
    my $oA = $oFONT->look_down('_tag', 'a');
    next TD unless ref $oA;
    my $sURL = $oA->attr('href');
    next TD unless $sURL =~ m!ViewItem!;
    my $sTitle = $oA->as_text;
    print STDERR " + TD ===$sTD===\n" if 1 < $self->{_debug};
    my ($iItemNum) = ($sURL =~ m!item=(\d+)!);
    my ($iPrice, $iBids, $sDate) = ('$unknown', 'no', 'unknown');
    # The rest of the info about this item is in sister TD elements to
    # the right:
    my @aoSibs = $oTD->right;
    # The next sister has the current bid amount (or starting bid):
    my $oTDprice = shift @aoSibs;
    if (ref $oTDprice)
      {
      if (1 < $self->{_debug})
        {
        my $s = $oTDprice->as_HTML;
        print STDERR " +   TDprice ===$s===\n";
        } # if
      $iPrice = $oTDprice->as_text;
      $iPrice =~ s!(\d)$W*($currency$W*[\d.,]+)!$1 (Buy-It-Now for $2)!;
      } # if
    # The next sister has the number of bids:
    my $oTDbids = shift @aoSibs;
    if (ref $oTDbids)
      {
      if (1 < $self->{_debug})
        {
        my $s = $oTDbids->as_HTML;
        print STDERR " +   TDbids ===$s===\n";
        } # if
      $iBids = $oTDbids->as_text;
      } # if
    # Bid listed as hyphen means no bids:
    $iBids = 'no' if $iBids =~ m!\A$W*-$W*\Z!;
    # Bid listed as whitespace means no bids:
    $iBids = 'no' if $iBids =~ m!\A$W*\Z!;
    my $sDesc = "Item \043$iItemNum; $iBids bid";
    $sDesc .= 's' if $iBids ne '1';
    $sDesc .= '; ';
    $sDesc .= 'no' ne $iBids ? 'current' : 'starting';
    $sDesc .= " bid $iPrice";
    # The last sister has the auction start date:
    my $oTDdate = pop @aoSibs;
    if (ref $oTDdate)
      {
      my $s = $oTDdate->as_HTML;
      print STDERR " +   TDdate ===$s===\n" if 1 < $self->{_debug};
      $sDate = $oTDdate->as_text;
      } # if
    my $hit = new WWW::Search::Result;
    $hit->add_url($sURL);
    $hit->title($sTitle);
    $hit->description($sDesc);
    $hit->change_date($sDate);
    $hit->raw($oTD->as_HTML);	# This is new to this Backend
    push(@{$self->{cache}}, $hit);
    $self->{'_num_hits'}++;
    $hits_found++;
    # Delete this HTML element so that future searches go faster!
    $oTD->detach;
    $oTD->delete;
    } # foreach

  # Look for a NEXT link:
  my @aoA = $tree->look_down('_tag', 'a');
 TRY_NEXT:
  foreach my $oA (reverse @aoA)
    {
    next TRY_NEXT unless ref $oA;
    print STDERR " +   try NEXT A ===", $oA->as_HTML, "===\n" if 1 < $self->{_debug};
    my $href = $oA->attr('href');
    next TRY_NEXT unless $href;
    # If we get all the way to the item list, there must be no next
    # button:
    last TRY_NEXT if $href =~ m!ViewItem!;
    if ($oA->as_text =~ m!Next$W+(>|&gt;)!i)
      {
      $self->{_next_url} = $self->absurl(undef, $href);
      print STDERR " +   got NEXT A ===", $self->{_next_url}, "===\n" if 1 < $self->{_debug};
      last TRY_NEXT;
      } # if
    } # foreach

  # All done with this page.
  $tree->delete;
  return $hits_found;
  } # parse_tree

1;

__END__


package EMA;
use strict;
use warnings;
no warnings 'once';

use List::Util qw( reduce max min );
use Scalar::Util qw( looks_like_number );

use base qw( Exporter );
our @EXPORT_OK = qw( get_balanced_ema get_generic_ema get_offset_ema );

=head2 get_balanced_ema
    Takes a list of numbers as input.
    
    Returns a list of numbers representing exponential moving 
=cut

sub get_balanced_ema {
    my ( $distance, $weight_exponent, @points ) = @_;
    
    my $offset = 0;
    
    return get_offset_ema( $distance, $offset, $weight_exponent, @points );
}

=head2 get_balanced_ema
=cut

sub get_offset_ema {
    my ( $distance, $offset, $weight_exponent, @points ) = @_;
    
    $distance = abs( $distance );
    my $lookaround_start = ( -1 * $distance ) + $offset;
    my $lookaround_end   = (      $distance ) + $offset;
    
    return get_generic_ema( $lookaround_start, $lookaround_end, $weight_exponent, @points );
}

=head2 get_balanced_ema
=cut

sub get_generic_ema {
    my ( $lookaround_start, $lookaround_end, $weight_exponent, @points ) = @_;
    
    @points = map undefine_non_numerical($_), @points;

    my %averages = map get_ema_average_for_point( $lookaround_start, $lookaround_end, $weight_exponent, $_, \@points ), ( 0 .. $#points );
    
    my @averages;
    $averages[$_] = $averages{$_} for keys %averages;
    
    return @averages;
}

# Internals

sub undefine_non_numerical {
    my ( $value ) = @_;
    
    return $value if looks_like_number( $value );
    
    return undef;
}

sub get_ema_average_for_point {
    my ( $lookaround_start, $lookaround_end, $weight_exponent, $point_index, $points ) = @_;
    
    my @factors = extract_factors ( $lookaround_start, $lookaround_end, $weight_exponent, $point_index, $points ) or return;
    
    my $total_weight = get_total_factors_weight( @factors ) or return;
    
    my $total_value = get_total_factors_value( @factors );
    
    my $average = $total_value / $total_weight;
    
    return ( $point_index => $average );
}

sub extract_factors {
    my ( $lookaround_start, $lookaround_end, $weight_exponent, $point_index, $points ) = @_;
    
    my @range = create_factor_range( $lookaround_start, $lookaround_end, $points, $point_index );
    my @factors = map build_factor( $points, $point_index, $weight_exponent, $_ ), @range;
    
    return @factors;
}

sub create_factor_range {
    my ( $lookaround_start, $lookaround_end, $points, $point_index ) = @_;
    
    my $range_size = $lookaround_end - $lookaround_start;
    my $min_factors = int( $range_size / 2 );
    my $last_point_index = $#{$points};
    
    my $range_start = $lookaround_start + $point_index;
    $range_start = max( 0, $range_start );
    my $range_end = $lookaround_end + $point_index;
    $range_end = min( $last_point_index, $range_end );
    
    my @range = ( $range_start .. $range_end );
    @range = grep { defined $points->[ $_ ] } @range;
    
    while( @range < $min_factors ) {
        $range_start--;
        $range_end++;
        push @range, $range_start if $range_start >= 0 and defined $points->[ $range_start ];
        push @range, $range_end if $range_end <= $last_point_index and defined $points->[ $range_end ];
        
        last if $range_start <= 0 and $range_end >= $last_point_index
    }
    
    return @range;
}

sub get_total_factors_weight {
    my ( @factors ) = @_;
    
    my $total_weight = reduce { $a + $b->{weight} } 0, @factors;
    
    return $total_weight;
}

sub get_total_factors_value {
    my ( @factors ) = @_;
    
    my $total_value = reduce { $a + $b->{weighted_value} } 0, @factors;
    
    return $total_value;
}

sub extract_factor {
    my ( $points, $point_index, $weight_exponent, $factor_index ) = @_;
    
    my $value = $points->[ $factor_index ];
    my $factor_distance = $factor_index - $point_index;
    my $factor = build_factor ( $value, $factor_distance, $weight_exponent );
    
    return $factor;
}

sub build_factor {
    my ( $points, $point_index, $weight_exponent, $factor_index ) = @_;
    
    my $value = $points->[ $factor_index ];
    my $factor_distance = $factor_index - $point_index;
    
    my %factor;
    
    $factor{value} = $value;
    $factor{distance} = abs( $factor_distance );
    $factor{weight} = $weight_exponent ** $factor{distance};
    $factor{weighted_value} = $factor{value} * $factor{weight};
    
    return \%factor;
}

1;

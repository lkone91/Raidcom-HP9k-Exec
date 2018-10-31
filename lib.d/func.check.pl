use strict;

    #-----------------------------------------------------------------#
    #------------------------ FONCTIONS CHECK ------------------------#
    #-----------------------------------------------------------------#

sub vol_size_check { #Arg @new_lun_lst @LUN_TYPE_LST
    
    my ($new_lun_lst, $lun_type_lst) = @_;
    
    my @new_lun_lst = @{ $new_lun_lst };
    my @lun_type_lst = @{ $lun_type_lst };
    
    my @new_lun_fmt_lst = ();
    
    for (@new_lun_lst) {
        
        my ($count, $gb) = split('x', $_);
        
        my $val_info = (grep {/^$gb;/} @lun_type_lst)[0];
        
        if ($val_info) {
            
            my $val_gb = (split(';', $val_info))[0];
            my $val_bk = (split(';', $val_info))[1];
        
            push(@new_lun_fmt_lst, "$count;$val_gb;$val_bk");
        
        } else {
            mprint("Value ${gb} Not Find", 'e');
        }
    }
    
    return @new_lun_fmt_lst;
}

1;
use strict;

    #---------------------------------------------------------------------#
    #------------------------ FONCTIONS AFFICHAGE ------------------------#
    #---------------------------------------------------------------------#    
 
sub get_bay_info { #Arg $inst $x @BAY_INFO_LST
    
    my ($inst, $x, $bay_info_lst) = @_;
    
    my @bay_info_lst = @{ $bay_info_lst };
    
    my $type = '';
    
    my $bay_info = (grep {/;${inst}$/} @bay_info_lst)[0];
    my $name = (split(';', $bay_info))[2];
    
    if ($x == 0) {
        $type = 'Local';
    
    } else {
        $type = 'Remote';
        
    }
    
    return ($type, $name);
    
}
 
sub display_lun_info { #Arg @inst_lst @lun_info_lst @BAY_INFO_LST
    
    my ($inst_lst, $lun_info_lst, $bay_info_lst) = @_;
    
    my @inst_lst = @{ $inst_lst };
    my @lun_info_lst = @{ $lun_info_lst };
    my @bay_info_lst = @{ $bay_info_lst };
    
    my $x = 0;
    
    mprint();
    mprint("[" .join(', ', @inst_lst). "] TDev Informations", 's1');
    mprint();
    
    for my $i (@inst_lst) {
        
        my ($bay_t, $bay_n) = get_bay_info($i, $x, \@bay_info_lst);
        
        mprint("${bay_t} Bay (${bay_n}) [I:${i}]", 's2');
        mprint();
        
        my @new_lun_info_lst = ();
        
        for (@lun_info_lst) {
            if ($_ =~ /^${i};/) { push(@new_lun_info_lst, $_); }
        }
        
        my $title = "Tdev;Name;Size;Used;Pool;Attr;Host Group";
        my @index = (0..6);
        
        my @data_lst = ();
        
        my @total_size_lst = get_column_uniq("2", \@new_lun_info_lst, 1);
        my $total_size = sum(@total_size_lst);
        my %lun_by_type_hsh = count(@total_size_lst);
            
        my @lun_by_type_lst = ();
            
        for my $h (keys %lun_by_type_hsh) {
            push(@lun_by_type_lst, "$lun_by_type_hsh{$h}x${h}");
        }
        
        mprint("Total Size\t: ${total_size}GB");
        mprint("Total Lun\t: ". scalar(@new_lun_info_lst));
        mprint("Lun by Type\t: ". join(',', @lun_by_type_lst));
        mprint();
        
        for (@new_lun_info_lst) {
            
            my ($inst, $tdev, $size, $host, $host_info, $attr, $used_prc, $pool_id, $name, $type) = split(/\;/, $_);
            
            if (! $host) { $host = 'No'; }
            
            push(@data_lst, "$tdev;$name;${size};${used_prc}%;$pool_id;$attr;$host");
        }
        
        table_display($title, \@data_lst, \@index);
        
        mprint();
        $x += 1;
    }
    
}
 
sub display_host_grp_info { #Arg $bay_name @host_info_lst @bay_info_lst
    
    my ($inst_lst, $host_info_lst, $bay_info_lst) = @_;
    
    my @inst_lst = @{ $inst_lst };
    my @host_info_lst = @{ $host_info_lst };
    my @bay_info_lst = @{ $bay_info_lst };
    
    my $x = 0;
    
    mprint();
    mprint("[" .join(', ', @inst_lst). "] Host Group Informations", 's1');
    mprint();
    
    for my $i (@inst_lst) {
        
        my ($bay_t, $bay_n) = get_bay_info($i, $x, \@bay_info_lst);
        
        mprint("${bay_t} Bay (${bay_n}) [I:${i}]", 's2');
        mprint();
        
        my @new_host_info_lst = ();
        
        for (@host_info_lst) {
            if ($_ =~ /^${i};/) { push(@new_host_info_lst, $_); }
        }
        
        my @host_lst = get_column_uniq("1", \@new_host_info_lst);
        
        for my $host (@host_lst) {
            
            mprint("Host Group Name : $host");
            mprint();
            
            my @data_lst = ();
            my $title = "Port;GID;OS;Dev;Login";
            my @index = (0..4);
            
            for (@new_host_info_lst) {
                
                if ($_ =~ /$host/) {
                    my ($inst, $hst, $port, $gid, $wwn, $dev_cnt, $dev_fmt, $os) = split(/\;/, $_);
                    push(@data_lst, "$port;$gid;$os;$dev_cnt;$wwn");
                }
            }
            
            table_display($title, \@data_lst, \@index);
            
            mprint();
        }
        
        $x += 1;
    }
}

sub display_copy_dev_grp_info { #Arg $inst_lst @copy_grp_lst @copy_group_info_lst @device_grp_info_lst
    
    my ($inst_lst, $copy_grp_lst, $copy_group_info_lst, $device_grp_info_lst) = @_;
    
    my @inst_lst = @{ $inst_lst };
    my @copy_grp_lst = @{ $copy_grp_lst };
    my @copy_group_info_lst = @{ $copy_group_info_lst };
    my @device_grp_info_lst = @{ $device_grp_info_lst };
    
    mprint();
    mprint("[" .join(', ', @inst_lst). "] Copy Group Informations", 's1');
    
    for my $copy_grp (@copy_grp_lst) {
        
        my ($cgroup, $dgroup, $sn, $dev_cnt) = split(';', $copy_grp);
        
        mprint();
        mprint("${cgroup} [DG:${dgroup}, D.Nb:$dev_cnt]", 's2');
        mprint();
        
        if (! @copy_group_info_lst) {
            
            my $title = "L.Dev;T.Name";
            my @index = (0..1);
            
            my @data_lst = ();
            
            for my $dg_info (@device_grp_info_lst) {
                my ($cg, $dg, $ldev, $ldev_name) = split(';', $dg_info);
                
                if ($dgroup =~ /${dg}/) {
                    push(@data_lst, "$ldev;$ldev_name");
                }
            }
            
            table_display($title, \@data_lst, \@index);
            
        } else {
            
            my $title = ";;L.Dev;Name;Type;R.Dev;R.Bay(SN);State;Prc";
            my @index = (2..8);
            
            my @data_lst = ();
            
            for my $cg_info (@copy_group_info_lst) {
                my ($cg, $dg, $ldev, $ldev_name, $type, $rdev, $rbay, $state, $prc) = split(';', $cg_info);
                
                if ($dgroup =~ /${dg}/) {
                    push(@data_lst, $cg_info);
                }
            }
            
            table_display($title, \@data_lst, \@index);
            
        }
    }
}
    
sub display_pool_info { #Arg $inst_lst @pool_info_lst @bay_info_lst
    
    my ($inst_lst, $pool_info_lst, $bay_info_lst) = @_;
    
    my @inst_lst = @{ $inst_lst };
    my @pool_info_lst = @{ $pool_info_lst };
    my @bay_info_lst = @{ $bay_info_lst };
    
    mprint();
    mprint("[" .join(', ', @inst_lst). "] Pool Informations", 's1');
    mprint();
    
    my $x = 0;
    
    for my $i (@inst_lst) {
        
        my ($bay_t, $bay_n) = get_bay_info($i, $x, \@bay_info_lst);
        
        mprint("${bay_t} Bay (${bay_n}) [I:${i}]", 's2');
        mprint();
        
        my @data_lst = ();
        my $title = "ID;Us.%;Ov.%;T.Sz;Av.Sz;D.Nb";
        my @index = (0..5);
        
        for (@pool_info_lst) {
            my ($pid, $pols, $tp_cap_fmt, $av_cap_fmt, $tl_cap_fmt, $us_prc, $cap_prc, $ldev_cnt, $inst) = split(/\;/, $_);
            if ($i == $inst) {
                push(@data_lst, "$pid;${us_prc}%;${cap_prc}%;$tl_cap_fmt;$av_cap_fmt;$ldev_cnt");
            }
        }
        
        table_display($title, \@data_lst, \@index, 2);
        
        $x += 1;
        mprint();
    }
    
}

1;

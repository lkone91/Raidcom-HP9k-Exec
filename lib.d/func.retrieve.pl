use strict;

my $marge = '. ';
my $load_printf = "${marge} %-32s ";

    #----------------------------------------------------------------------#
    #------------------------ FONCTIONS RECUP INFO ------------------------#
    #----------------------------------------------------------------------#

sub get_user {
	
    my @user_login_info_lst = split(/\n/ , `ps auxwww 2>&- | grep sshd | grep pts 2>&-`);
    my $current_user_pts = "pts/".(split('\/', (split(/\n/, `tty 2>&-`))[0]))[3];
    
    my @user_lst = ();
    
    for (@user_login_info_lst) {
        
        my @split_cmd = split(/\s+/, $_);
        
        if ($split_cmd[10] =~ /sshd:/ and $split_cmd[11] =~ /${current_user_pts}/) {
            push(@user_lst, (split('@', $split_cmd[11]))[0]);
        }
    
    }
    
    return join(',', uniq(@user_lst));
}
    
sub get_remote_info { #Arg $logger, $local_inst

    my ($logger, $inst) = @_;
    
    $logger->write_log("INFO", "[RETRIEVE] Get Bay Remote Info");
    
    my $local_service = "";
    my $remote_inst = "";
    my $remote_service = "";
    
    if (length ($inst) == 2) {
        $local_service = "310${inst}";
        $remote_inst = "1${inst}";
        $remote_service = "311${inst}";
    
    } else {
        $local_service = "31${inst}";
        $remote_inst = join('', (split('', $inst))[1,2]);
        $remote_service = "310" . join('', (split('', $inst))[1,2]);
    }
    
    return ($local_service, $remote_inst, $remote_service);
}
    
sub get_host_list { #Arg $logger $inst @srv_name_lst
    
    my ($logger, $inst, $srv_name_lst) = @_;
    my @srv_name_lst = @{ $srv_name_lst };
    
    printf($load_printf, "Retrieving HG List (${inst})");
    
    $logger->write_log("INFO", "[RETRIEVE] Retrieving HG List (${inst})");
    
    my @port_lst = cmd_retrieve("raidcom get port -I${inst}", $logger);
    
    my @host_port_lst = ();
    
    for my $port (@port_lst) {
        
        if ($port =~ /^CL[0-9]+/) {
            
            my (
                $port, $type, $attr, $spd, $lpid, $fab, $conn, $ssw, $sl, $sn, $wwn, $phy
            ) = split(/\s+/, $port);
            
            my @host_info_spt = cmd_retrieve("raidcom get host_grp -port ${port} -I${inst}");
            
            for (@host_info_spt) {
                
                my ($port, $gid, $grp, $sn, $hmd, $hmo) = split(/\s+/, $_);
                
                for (@srv_name_lst) {
                    
                    if ($grp =~ /${_}$/) {
                
                        if ($port =~ /^CL[0-9]+/ and $grp !~ /^[0-9]+[A-Z]\-G[0-9]+$/) {
                            push(@host_port_lst, "${grp}:${port}:${gid}");
                        }
                    } 
                }
            }
        }
    }
    
    print("[done]\n");
    return @host_port_lst;

}

sub get_pool_info { #Arg $logger @inst_lst
    
    my ($logger, @inst_lst) = @_;
    
    printf($load_printf, "Retrieving Pool Info (" .join(', ', @inst_lst). ")");
    
    $logger->write_log("INFO", "[RETRIEVE] Retrieving Pool Info (" .join(', ', @inst_lst). ")");
    
    my @pool_info_lst = ();
    
    for (@inst_lst) {
        
        my @pool_cmd_lst = cmd_retrieve("raidcom get thp_pool -I${_}", $logger);
        
        for my $pool_cmd (@pool_cmd_lst) {
            if ($pool_cmd !~ /^PID/) {
                my ($pid, $pols, $us_prc, $av_cap, $tp_cap, $w_prc, $h_prc, $num, $ldev_cnt, $lcnt, $tl_cap, $bm, $tr_cap, $rcnt) = split(/\s+/, $pool_cmd);
                
                $pid = int($pid);
                $pols = substr($pols, 3);
                
                my $tp_cap_fmt = size_conv($tp_cap, 'MB', 1);
                my $av_cap_fmt = size_conv($av_cap, 'MB', 1);
                my $tl_cap_fmt = size_conv($tl_cap, 'MB', 1);
                
                my $cap_prc = int($tl_cap * 100 / $tp_cap);
                
                push(@pool_info_lst, "$pid;$pols;$tp_cap_fmt;$av_cap_fmt;$tl_cap_fmt;$us_prc;$cap_prc;$ldev_cnt;$_");
                
            }
        }
    
    }
    
    print("[done]\n");
    return @pool_info_lst;  
}

sub get_available_tdev { #Arg $logger @inst_lst $last_id $device_cnt $count
    
    my $logger = shift;
    my $inst_lst = shift;
    my $last_id = shift;
    my $device_cnt = shift;
    my $count = shift || 500;
    
    my @inst_lst = @{ $inst_lst };
    
    $device_cnt -= 1;
    
    printf($load_printf, "Retrieving Av. L.Dev (" .join(', ', @inst_lst). ")");
    
    $logger->write_log("INFO", "[RETRIEVE] Retrieving Av. L.Dev (" .join(', ', @inst_lst). ")");
    
    my @av_ldev_lst = ();
    
    for (@inst_lst) {
        
        my @av_ldev_cmd_lst = cmd_retrieve("raidcom get ldev -fx -key front_end -ldev_id ${last_id} -cnt ${count} -I${_} | grep \"NOT DEFINED\"", $logger);
        
        for my $cmd (@av_ldev_cmd_lst) {
            my ($x, $sn, $tdev, $a, $b, $not, $def, $c, $d, $e, $f) = split(/\s+/, $cmd);
            
            if ($sn !~ /Serial#/) {
                
                if (scalar(@inst_lst) > 1) {
                    push(@av_ldev_lst, "$_;$tdev");
                } else {
                    push(@av_ldev_lst, $tdev);
                }
            } 
        }
    }
    
    if (scalar(@inst_lst) > 1) {
        
        my @first_list = ();
        my @second_list = ();
        
        for (@av_ldev_lst) {
            my ($inst, $tdev) = split(';', $_);
            if ($inst == $inst_lst[0]) {
                push(@first_list, $tdev);
            }
        }
            
        for (@av_ldev_lst) {
            my ($inst, $tdev) = split(';', $_);
            if ($inst == $inst_lst[1]) {
                push(@second_list, $tdev);
            }
        }
        
        @av_ldev_lst = ();
        
        for (@first_list) {   
            if (grep {/^$_$/} @second_list) {
                push(@av_ldev_lst, $_);
            }
        }  
    }
    
    print("[done]\n");
    return @av_ldev_lst[0..${device_cnt}];
    
}
    

sub get_host_info { #Arg $logger $inst, @host_port_lst, $host_tmp_name
    
    my ($logger, $inst, $host_port_lst, $host_tmp_name) = @_;
    my @host_port_lst = @{ $host_port_lst };
    
    my $host_tmp_exist_check = 0;
    
    printf($load_printf, "Retrieving HG Info (${inst})");
    
    $logger->write_log("INFO", "[RETRIEVE] Retrieving HG Info (${inst})");
    
    my @host_info_lst = ();
    
    for (@host_port_lst) {
        
        my ($grp, $port, $gid) = split(':', $_);
        
        ### Lun Info ###
        
        my @ldev_lst = ();
        my @os_lst = ();
        
        my @lun_cmd_lst = cmd_retrieve("raidcom get lun -port ${port}-${gid} -fx -I${inst}", $logger);
        
        if (@lun_cmd_lst) {
            
            for my $lun_info (@lun_cmd_lst) {
                
                my ($port, $gid, $hmd, $lun, $num, $ldev, $cm, $sn, $hmo) = split(/\s+/, $lun_info);
                
                if ($ldev !~ /LDEV/) {
                    push(@ldev_lst, $ldev);
                    push(@os_lst, $hmd);
                }
            }
        } 
        
        my $ldev_cnt = scalar(@ldev_lst);
        my $ldev_join = join(',', @ldev_lst);
        
        my $os_join = join('|', uniq(@os_lst));
        
        ### Logins Info ###
        
        my @wwn_cmd_lst = cmd_retrieve("raidcom get hba_wwn -port ${port}-${gid} -fx -I${inst}", $logger);
        
        my @wwn_lst = ();
        
        for (@wwn_cmd_lst) {
            
            if ($_ =~ /^CL[0-9]+/) {
                push (@wwn_lst, (split(/\s+/, $_))[3]);
            }
        }
        
        my $wwn = join(',', @wwn_lst);
        
        if (! $wwn) { $wwn = 'No'; }
        
        push(@host_info_lst, "$inst;$grp;$port;$gid;$wwn;$ldev_cnt;$ldev_join;$os_join");
        
        if ($grp =~ /^${host_tmp_name}$/) {
            $host_tmp_exist_check = 1;
        }
    
    }
    
    print("[done]\n");
    return (\@host_info_lst, $host_tmp_exist_check);
    
}


sub get_lun_lst { #Arg $logger @host_info_lst
    
    my ($logger, @host_info_lst) = @_;
    
    my @ldev_lst = ();
    
    $logger->write_log("INFO", "[RETRIEVE] Get Lun List");
    
    for my $h (@host_info_lst) {
        my ($inst, $hst, $port, $gid, $wwn, $dev_cnt, $dev_fmt, $os) = split(/\;/, $h);
        
        if ($dev_cnt != 0) {
            
            my @dev_lst = split(',', $dev_fmt);
            
            for (@dev_lst) {
                push(@ldev_lst, $_);
            }
        }
    }
    
    return uniq(@ldev_lst);
    
}

sub get_lun_detail { #Arg $logger, $inst, @ldev_lst
    
    my ($logger, $inst, $ldev_lst) = @_;
    
    my @ldev_lst = @{ $ldev_lst };
    
    printf($load_printf, "Retrieving Lun Info ($inst)");
    
    $logger->write_log("INFO", "[RETRIEVE] Retrieving Lun Info ($inst)");
    
    my @lun_info_lst = ();
    
    for my $ldev (@ldev_lst) {
        
        my @lun_cmd_lst = cmd_retrieve("raidcom get ldev -ldev_id 0x${ldev} -fx -I${inst}", $logger);
        
        my @port_lst = split(" : ", (grep {/^PORTs :/} @lun_cmd_lst)[0]);
        
        my @port_gid_lst = ();
        my @port_gid_fmt_lst = ();
        my @host_nm_lst = ();
        
        for (@port_lst) {
            if ($_ =~ /^CL[0-9]+/) {
                
                my ($port_gid, $id, $grp) = split(/\s+/, $_);
                my @port_gid_spt = split('-', $port_gid);
                my $port_fmt = substr($port_gid_spt[0], 2);
                
                push(@port_gid_lst, "$grp:$port_gid_spt[0]-$port_gid_spt[1]:$port_gid_spt[2]");
                push(@port_gid_fmt_lst, "$grp;${port_fmt}$port_gid_spt[1]$port_gid_spt[2]:${id}");
                push(@host_nm_lst, $grp);
                
            }
        }
        
        my %host_nm_hsh = count(@host_nm_lst);
        
        @host_nm_lst = ();
        
        for my $h (keys %host_nm_hsh) {
            
            my @pgid_fmt_lst = ();
            
            for (@port_gid_fmt_lst) {
                my ($grp, $pgid_fmt) = split(';', $_);
                
                if ($grp =~ /^$h$/) {
                    push(@pgid_fmt_lst, $pgid_fmt);
                }
                
            }
            
            my $pgid_fmt = join('|', sort(@pgid_fmt_lst));
            
            push (@host_nm_lst, "$h\[${pgid_fmt}\]\($host_nm_hsh{$h}\)");
        }
        
        my $port_gid = join(",", @port_gid_lst);
        my $host_nm = join(",", @host_nm_lst);
        my @vol_attr_lst_a = (split(" : ", (grep {/^VOL_ATTR :/} @lun_cmd_lst)[0]));
        
        my @vol_attr_lst = ();
        
        foreach (@vol_attr_lst_a) {
            if ($_ !~ /VOL_ATTR/) {
                push (@vol_attr_lst, $_);
            }
        }
        
        my $vol_type = (split(" : ", (grep {/^VOL_TYPE :/} @lun_cmd_lst)[1]))[1];
        my $tdev_name = (split(" : ", (grep {/^LDEV_NAMING :/} @lun_cmd_lst)[0]))[1];
        my $size_blk = (split(" : ", (grep {/^VOL_Capacity\(BLK\) :/} @lun_cmd_lst)[0]))[1];
        my $used_size_blk = (split(" : ", (grep {/^Used_Block\(BLK\) :/} @lun_cmd_lst)[0]))[1];
        
        my $type = 'Dv';
        my $pool_id = '';
        
        if ($vol_type !~ /CM/) {
            $type = 'Cm';
            $pool_id = (split(" : ", (grep {/^B_POOLID :/} @lun_cmd_lst)[0]))[1];
            
        } else {
            $pool_id = (split(" : ", (grep {/^NUM_GROUP :/} @lun_cmd_lst)[0]))[1];
        }
        
        my $vol_attr = join('|', @vol_attr_lst);
        
        my $used_prc = int($used_size_blk * 100 / $size_blk);
        my $size = size_conv($size_blk, 'BK');
        
        push(@lun_info_lst, "$inst;$ldev;$size;$host_nm;$port_gid;$vol_attr;$used_prc;$pool_id;$tdev_name;$type;$size_blk");
        
    }
    
    print("[done]\n");
    return @lun_info_lst;
    
}


sub get_device_grp_detail { #Arg $logger $inst @ldev_lst
    
    my ($logger, $inst, $ldev_lst) = @_;
    my @ldev_lst = @{ $ldev_lst };
    
    printf($load_printf, "Retrieving DG Info ($inst)");
    
    $logger->write_log("INFO", "[RETRIEVE] Retrieving DG Info ($inst)");
    
    my @device_grp_tdev_info_lst = ();
    my @copy_grp_lst = ();
    
    my @copy_grp_cmd_lst = cmd_retrieve("raidcom get copy_grp -I${inst}", $logger);
    
    for my $copy_grp_cmd (@copy_grp_cmd_lst) {
        
        my ($cg, $dg, $mu, $jid, $sn) = split(/\s+/, $copy_grp_cmd);
        
        my @copy_grp_info_cmd_lst = cmd_retrieve("raidcom get device_grp -device_grp_name ${dg} -fx -I${inst}");
        
        my $dev_count = scalar(@copy_grp_info_cmd_lst) - 1;
        
        for my $copy_grp_info_cmd (@copy_grp_info_cmd_lst) {
            
            my ($dg, $ldev_name, $ldev, $sn) = split(/\s+/, $copy_grp_info_cmd);
            
            for (@ldev_lst) {
                if ($_ =~ /^${ldev}$/) {
                    push(@device_grp_tdev_info_lst, "$cg;$dg;$ldev;$ldev_name");
                    push(@copy_grp_lst, "$cg;$dg;$sn;$dev_count");
                }
            }
            
        }
    }
    
    @copy_grp_lst = uniq(@copy_grp_lst);
    
    print("[done]\n");
    return \@device_grp_tdev_info_lst, \@copy_grp_lst;
    
}
   

sub get_copy_grp_detail { #Arg $logger $inst @copy_grp_lst @BAY_INFO_LST
    
    my ($logger, $inst, $copy_grp_lst, $bay_info_lst) = @_;
    my @copy_grp_lst = @{ $copy_grp_lst };
    my @bay_info_lst = @{ $bay_info_lst };
    
    my @copy_group_info_lst = ();
    
    printf($load_printf, "Retrieving CG Info ($inst)");
    
    $logger->write_log("INFO", "[RETRIEVE] Retrieving CG Info ($inst)");
    
    for my $copy_grp (@copy_grp_lst) {
        
        my @copy_group_line_lst = ();
        
        my ($cg, $dg, $sn, $dev_cnt) = split(';', $copy_grp);
        
        my @pairdisplay_cmd_lst = cmd_retrieve("pairdisplay -g ${cg} -fcxe -I${inst}", $logger);
        
        for my $pairdisplay_cmd (@pairdisplay_cmd_lst) {
            
            my ($cg, $vol_name_type, $pr_gid, $a, $id_bsn, $dev_vol, $state, $state2, $b, $prc, $d, $g, $h, $i, $j, $k, $l, $m, $n, $o, $p) = split(/\s+/, $pairdisplay_cmd);
            
            if ($vol_name_type !~ /PairVol/) {
            
                my ($vol_name, $type) = split('\(', $vol_name_type);
                my @port_gid_lst = split('-', $pr_gid);
                my $bay_sn = (split('\)', $id_bsn))[1];
                my ($vol, $dev_type) = split('\.', $dev_vol);
                
                push(@copy_group_line_lst, "$cg;$vol_name;$type;$bay_sn;$vol;$dev_type;$state;$prc");
            
            }
            
        }
        
        my @tdev_name_lst = get_column_uniq("1", \@copy_group_line_lst);
        
        for (@tdev_name_lst) {
            
            my $type = 'Local';
            
            my @cg_info_lst = ();
            
            for my $cg_line (@copy_group_line_lst) {
                if ($cg_line =~ /;${_};/) {
                    push(@cg_info_lst, $cg_line);
                }
            }
            
            my $dev_local_info = (grep {/L\)/} @cg_info_lst)[0];
            my $dev_remote_info = (grep {/R\)/} @cg_info_lst)[0];
            
            my ($loc_cg, $loc_vol_name, $loc_type, $loc_bay_sn, $loc_vol, $loc_dev_type, $loc_state, $loc_prc) = split(';', $dev_local_info);
            my ($rmt_cg, $rmt_vol_name, $rmt_type, $rmt_bay_sn, $rmt_vol, $rmt_dev_type, $rmt_state, $rmt_prc) = split(';', $dev_remote_info);
            
            my $remote_bay_info = (grep {/;${rmt_bay_sn};/} @bay_info_lst)[0];
            my $remote_bay_name = (split(';', $remote_bay_info))[2];
            
            if ($loc_dev_type =~ /S-VOL/) { $type = 'Remote' }
            
            push(@copy_group_info_lst, "$cg;$dg;$loc_vol;$loc_vol_name;$type;$rmt_vol;${remote_bay_name}(${rmt_bay_sn});$loc_state;${loc_prc}%");
            
        }
    }
    
    print("[done]\n");
    return @copy_group_info_lst;
}
  
1;  
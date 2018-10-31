use strict;

my $marge = '. ';
my $load_printf = "${marge} %-32s ";

    #--------------------------------------------------------------------#
    #------------------------ FONCTIONS INSTANCE ------------------------#
    #--------------------------------------------------------------------# 
  
sub get_current_instance { #Arg $logger
    
    my ($logger) = @_;
    
    my @current_horcm_inst_lst = ();
    my @horcm_process_inst_list = split("\n", `ps -eaf | grep -iE 'horcmd_[0-9]+'`);
    
    foreach my $h (@horcm_process_inst_list) {
        my $daemon_inst = (split(/\s+/, $h))[-1];
        push(@current_horcm_inst_lst, int((split("_", $daemon_inst))[1]));
    }
    
    return @current_horcm_inst_lst;
    
}

sub start_instance { #Arg $inst $horcm_bin_path
    
    my ($inst, $horcm_bin_path) = @_;
    
    system("${horcm_bin_path}/horcmstart.sh ${inst} > /dev/null 2>&1");
    
    if (! grep {/^$inst$/} (get_current_instance())) {
        return 1;
    }
    
    return 0;
}

sub stop_instance { #Arg $inst $horcm_bin_path
    
    my ($inst, $horcm_bin_path) = @_;
    
    system("${horcm_bin_path}/horcmshutdown.sh ${inst} > /dev/null 2>&1");
    
    sleep(5);
    
    if (grep {/^$inst$/} (get_current_instance())) {
        return 1;
    }
    
    return 0;
}


sub set_instance { #Arg $logger $inst $action $horcm_bin_path
    
    my ($logger, $inst, $action, $horcm_bin_path) = @_;
    
    printf($load_printf, "${action} Instance \(${inst}\)");
    
    my $inst_return = 0;
    
    if ($action =~ /Start/) {
        $inst_return = start_instance($inst, $horcm_bin_path);
        
        if ($inst_return != 0) {
            
            print("[fail!]\n");
            
            mprint("Instance ${inst} not Start : ${inst_return}", 'e', '', $logger);
            
        }
        
    } elsif ($action =~ /Stop/) {
        $inst_return = stop_instance($inst, $horcm_bin_path);
          
        if ($inst_return != 0) {
            
            print("[fail!]\n");
            
            mprint("Instance ${inst} not Stop : ${inst_return}", 'e', '', $logger);
        }
        
        if ($inst_return != 0) { s_exit(1); }
        
    } elsif ($action =~ /Reload/) {
        $inst_return = stop_instance($inst, $horcm_bin_path);
        
        if ($inst_return != 0) {
            print("[fail!]\n");
            
            $logger->write_log("WARNING", "Instance ${inst} not Stop : ${inst_return}");
            
            return 1; 
        }
        
        $inst_return = start_instance($inst, $horcm_bin_path);
        
        if ($inst_return != 0) {
            print("[fail!]\n");
            
            $logger->write_log("WARNING", "Instance ${inst} not Start : ${inst_return}");
            
            return 1;
        }
    }
    
    print("[done]\n");
    return 0
}

    #-------------------------------------------------------------------#
    #------------------------ FONCTIONS FICHIER ------------------------#
    #-------------------------------------------------------------------#

sub set_horcm_conf_file { #Arg $logger $inst $horcm_conf_path $backup_dir @copy_grp_lst @bay_info_lst

    my ($logger, $local_ins, $horcm_conf_path, $backup_dir, $copy_grp_lst, $bay_info_lst) = @_;
    my @copy_grp_lst = @{ $copy_grp_lst };
    my @bay_info_lst = @{ $bay_info_lst };
    
    my @backup_file_lst = ();
    my $conf_file_check = 0;
    
    my ($year, $mon, $day, $hour, $min, $sec) = split(/\s+/, `date "+%Y %m %d %H %M %S"`);
    my ($local_service, $remote_ins, $remote_service) = get_remote_info($logger, $local_ins);
    
    my $local_conf_file = "${horcm_conf_path}/horcm${local_ins}.conf;Local";
    my $remote_conf_file = "${horcm_conf_path}/horcm${remote_ins}.conf;Remote";
    
    printf($load_printf, "Backup Conf Files \($local_ins, $remote_ins\)");
    
    for my $conf_file_mode (($local_conf_file, $remote_conf_file)) {
        
        my ($conf_file, $mode) = split(';', $conf_file_mode);
        
        if (-e $conf_file) {
        
            my $file_name = (split('/', $conf_file))[-1];
            my $backup_file = "${backup_dir}/${file_name}.${year}${mon}${day}_${hour}${min}${sec}.bck";
            
            copy($conf_file, $backup_file) or mprint("Copy failed [${conf_file} > ${backup_file}] : $!", 'e', '', $logger);
            
            push(@backup_file_lst, "$conf_file:$backup_file");
            
        } else {
            mprint();
            mprint(" ${mode} Config File Not Find \[${conf_file}\] ...", 'e', '', $logger);
            
        }
    }
    
    print("[done]\n");
    
    for my $conf_file_mode (($local_conf_file, $remote_conf_file)) {
        
        my ($conf_file, $mode) = split(';', $conf_file_mode);
        
        my $file_name = (split('/', $conf_file))[-1];
        my $name = substr((split('\.', $file_name))[0], 5);
        
        printf($load_printf, "Check ${mode} Conf File \(${name}\)");
        
        for my $line (@copy_grp_lst) {
            
            my ($lcl_grp, $lcl_dg, $sn, $dev_cnt) = split(';', $line);
            
            my ($lcl_ip, $lcl_srv, $lcl_name, $lcl_sn) = split(';', join('', (grep({/\;${local_service}\;/} @bay_info_lst))));
            my ($rmt_ip, $rmt_srv, $rmt_name, $rmt_sn) = split(';', join('', (grep({/\;${remote_service}\;/} @bay_info_lst))));
            
            my $local_ldevg = "HORCM_LDEVG:${lcl_grp};${lcl_dg};${lcl_sn}";
            my $local_inst =  "HORCM_INST:${lcl_grp};${rmt_ip};${rmt_srv}";
            
            my $remote_ldevg = "HORCM_LDEVG:${lcl_grp};${lcl_dg};${rmt_sn}";
            my $remote_inst =  "HORCM_INST:${lcl_grp};${lcl_ip};${lcl_srv}";
            
            my $bay_name = '';
            my @horcm_mode_lst = ();
            
            if ($mode =~ /Local/) {
                $bay_name = $lcl_name;
                @horcm_mode_lst = ($local_ldevg, $local_inst);
                
            } else { 
                $bay_name = $rmt_name;
                @horcm_mode_lst = ($remote_ldevg, $remote_inst);
            }
            
            for my $horcm_mode (@horcm_mode_lst) {
                
                my $new_file = '';
                my ($h_mode, $h_line) = split(':', $horcm_mode);
                
                my ($exist_check, $comment_check) = check_conf_file($logger, $conf_file, $h_line);
                
                if ($exist_check == 1) {
                    if ($comment_check == 1) {
                        
                        $new_file = replace_line_conf_file($logger, $conf_file, $h_line, $h_line);
                        copy($new_file, $conf_file) or mprint("Copy failed [${new_file} > ${conf_file}] : $!", 'e', '', $logger);
                        
                        $conf_file_check = 1;
                        
                    }
                    
                } else {
                    
                    $new_file = add_line_conf_file($logger, $conf_file, $h_line, $h_mode);
                    copy($new_file, $conf_file) or mprint("Copy failed [${new_file} > ${conf_file}] : $!", 'e', '', $logger);
                    
                    $conf_file_check = 1;
                 
                }   
            }
        }
        
        print("[done]\n");
        
    }
    
    return $conf_file_check, \@backup_file_lst;
}

sub check_conf_file { #Arg $logger $file $line_toc
    
    my ($logger, $file, $line_toc) = @_;
    
    my ($grp, $dg_ip, $sn_sv) = split(';', $line_toc);
    
    open(my $in, '<', $file) or mprint("Can't read old file: $!", 'e', '', $logger);
    
    my $exist_check = 0;
    my $comment_check = 0;
    
    while(<$in>) {
    
        if ($_ =~ /${grp}\s+${dg_ip}\s+${sn_sv}/) {
            $exist_check = 1;
            
            if ($_ =~ /^\s*#/) {
                $comment_check = 1;
            }
        }
    }
    
    return ($exist_check, $comment_check);
    
}

sub add_line_conf_file { #Arg $logger $file $line_tow $last

    my ($logger, $file, $line_tow, $last) = @_;
    
    my $file_new = "$file.new";
    my ($grp, $dg_ip, $sn_sv) = split(';', $line_tow);
    
    open(my $in, '<', $file) or mprint("Can't read old file: $!", 'e', '', $logger);
    open(my $out, '>', $file_new) or mprint("Can't write new file: $!", 'e', '', $logger);
    
    my $check = 0;
    
    while(<$in>) {
        print($out $_);
        
        if ($check == 1) {
            
            next if /^(\s*#)/;
            print($out "${grp}\t${dg_ip}\t${sn_sv}\n");
            $check = 0;
        
        } elsif ($_ =~ /^${last}/) {
            $check = 1;
        }
    }
    
    close $out;
    
    return $file_new;
    
}

sub replace_line_conf_file { #Arg $logger, $file $line_tow $last

    my ($logger, $file, $line_tow, $last) = @_;
    
    my $file_new = "$file.new";
    my ($grp, $dg_ip, $sn_sv) = split(';', $line_tow);
    
    open(my $in, '<', $file) or mprint("Can't read old file: $!", 'e', '', $logger);
    open(my $out, '>', $file_new) or mprint("Can't write new file: $!", 'e', '', $logger);
    
    my $check = 0;
    
    while(<$in>) {
        
        if ($_ !~ /${grp}\s+${dg_ip}\s+${sn_sv}/) {
            print $out $_;
        } else {
            print $out "${grp}\t${dg_ip}\t${sn_sv}\n";
        }
        
    }
    
    close $out;
    
    return $file_new;
    
}

sub restore_conf_file { #Arg $logger @backup_file_lst $inst $remote_inst $horcm_bin_path
    
    my ($logger, $backup_file_lst, $inst, $remote_inst, $horcm_bin_path) = @_;
    my @backup_file_lst = @{ $backup_file_lst };
    
    my $inst_return = 0;
    
    printf($load_printf, "Restore Cf.File \($inst, $remote_inst\)");
    
    for (@backup_file_lst) {
        my ($original, $backup) = split(':', $_);
        
        copy($backup, $original) or mprint("Copy failed [${backup} > ${original}] : $!", 'e', '', $logger);
        
    }
    
    print("[done]\n");
    
    for (($inst, $remote_inst)) {
        
        my @current_horcm_inst_lst = get_current_instance();
    
        if (! grep {/^$_$/} @current_horcm_inst_lst) {
            my $inst_return = set_instance($_, 'Start', $horcm_bin_path);

        } else {
            my $inst_return = set_instance($_, 'Reload', $horcm_bin_path);
        
        }
        
        if ($inst_return != 0) {
            mprint("Problem with HORCM Config File ($_). Check it", 'e', '', $logger);
            
        }
    }  
}

1;

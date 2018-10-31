#!/usr/bin/perl
#
#---------------------------------------------------------------------------
# Script    : hp9k_exec.pl                                                 |
# Author    : L.Koné                                                       |
# Language  : Perl                                                         |
# Lib Dir   : lib.d                                                        |
# Version   : v0.01                                                        |
# Date      : 11/10/2017                                                   |
#---------------------------------------------------------------------------
#

use strict;
# use warnings;

use Data::Dumper qw(Dumper);
use File::Copy qw(copy);
use List::Util qw(sum);
use List::Util qw(max);

use FindBin qw($Bin $Script);

my $log_path = "${Bin}/log.d";
my $backup_path = "${Bin}/bck.d";
my $lib_path = "${Bin}/lib.d";

my $tmp_path = "/tmp";

my $horcm_bin_path = '/opt/HPtools/HORCM';
my $horcm_conf_path = '/opt/HPtools/HORCM/etc';

if (! -e $horcm_bin_path) { print("<!> HORCM Path not Find ! [${horcm_bin_path}]; exit()\n"); exit 1; }
if (! -e $horcm_conf_path) { print("<!> HORCM Config Path not Find ! [${horcm_conf_path}]; exit()\n"); exit 1; }

if (! -e $lib_path) { print("<!> Library Path not Find ! [${lib_path}]; exit()\n"); exit 1; }

for my $lib_file (("func.check.pl", "func.display.pl", "func.global.pl", "func.retrieve.pl", "func.file.pl", "class.logger.pl", )) {
    
    if (! -e "${lib_path}/$lib_file") { print("<!> Lib File [${lib_file}] not Find !; exit()\n"); exit 1; }
    
    require "${lib_path}/${lib_file}"; 
    
}

if (`whoami` !~ /root/) { print("<!> You Must be root; exit()\n"); exit 1; }

#-------------------------------------------------------------------------------------------------------------------------------#
#------------------------------------------------- DECLARATION VARIABLES/PATHS -------------------------------------------------#
#-------------------------------------------------------------------------------------------------------------------------------#

my @backup_file_lst = ();
my @hg_tmp_check_lst = ();
my @device_grp_info_lst = ();
my @copy_group_info_lst = ();
my @lun_info_lst = ();
my @host_info_lst = ();
my @pool_info_lst = ();
my @host_lst = ();
my @host_nm_lst = ();
my @host_port_lst = ();
my @ldev_lst = ();
my @host_all_lst = ();
my @copy_grp_lst = ();
my @hg_to_rm_lst = ();
my @lun_lst = ();
my @cg_lst = ();
my @av_dev_lst = ();
my @pool_choice_lst = ();

my $table = '';

my $host_tmp_name = 'HG_FORTIS_TEMP';
my $host_tmp_port = 'CL5-M';
my $host_tmp_gid = '79';

my @BAY_INFO_LST = (
    "localhost;30000;HP_BAY_1;82500;86",  
    "localhost;30001;HP_BAY_2;82501;87",  
);
  
my @horcm_inst_lst = ();
  
for (@BAY_INFO_LST) { push(@horcm_inst_lst, (split(';', $_))[-1]); }
  
my @LUN_TYPE_LST = (
    "1;2097152",
    "17;35651584",
    "34;71303168",
    "68;142606336",
    "102;213909504",
    "136;285212672",
    "272;570425344",
    "306;641728512",
    "374;784334848",
    "408;855638016",
    "510;1069547520",
    "612;1283457024",
    "816;1711276032",
    "1020;2139095040",
);

my @av_lun_size_lst = ();

for (@LUN_TYPE_LST) { push(@av_lun_size_lst, (split(';', $_))[0]); }


#---------------------------------------------------------------------------------------------------------------------#
#------------------------------------------------- GESTION ARGUMENTS -------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------#
    
my $usage = "
    
 Syntax
------------------------------------
 ./hp9k_exec.pl -h [Help]
 ./hp9k_exec.pl -i <inst> info|remove|delete -s <server>|-l <lun list>
 ./hp9k_exec.pl -i <inst> create -s <server> -nlun <new lun>
 
  <-nlun> Syntax\t: 1x126,3x216...
  
 Example
------------------------------------
 ./hp9k_exec.pl -i 86 info -s SERVER
 ./hp9k_exec.pl -i 87 remove -l 3daf,3eaa
 
  
 Available Lun|Instance
------------------------------------
  Lun Size\t: ". join(',', @av_lun_size_lst) ."
  Instance\t: ". join(',', @horcm_inst_lst) ."
  
";
   
my $arg_error_msg = "\n <!> Bad Argument\n${usage}";   
    
if ($ARGV[0] =~ /-h/) { print($usage); exit; }
  
if (scalar(@ARGV) !~ /^(5|7)/) { print($arg_error_msg); exit; }

if ($ARGV[0] !~ /^-i$/ or $ARGV[2] !~ /^(remove|info|delete|create)$/ or $ARGV[3] !~ /^(-s|-l)$/) {
    print($arg_error_msg); exit;
}

my $inst = $ARGV[1];
my $mode = $ARGV[2];
my $device = $ARGV[3];

my @srv_name_lst = ();
my @ldev_arg_lst = ();
my @new_lun_lst = ();

if ($device =~ /-s/) {
    @srv_name_lst = split(',', uc($ARGV[4]));
    
    if (grep {/(HG_|hg_)/} @srv_name_lst) {
        print("Only Server Name with '-s' Option. Example : DPWAN610\n");
        exit;
    }

} elsif ($device =~ /-l/) {
    @ldev_arg_lst = split(',', lc($ARGV[4]));
    
}

my $total_mode = 0;

if ($mode =~ /delete/) {
    $mode = 'remove';
    $total_mode = 1;
    
}

if ($mode =~ /create/) {
    
    if ($ARGV[5] !~ /^-nlun$/ or scalar(@ARGV) != 7 or $device =~ /-l/) { print($arg_error_msg); exit; }
    
    ### Vérif Standard Lun ###
    
    @new_lun_lst = split(',', lc($ARGV[6]));
    @new_lun_lst = vol_size_check(\@new_lun_lst, \@LUN_TYPE_LST);
    
} else {
    
    if (scalar(@ARGV) != 5) { print($arg_error_msg); exit; }

}

#====================================================================================================================#
#--------------------------------------------------------------------------------------------------------------------#
#------------------------------------------------- DEMARRAGE SCRIPT -------------------------------------------------#
#--------------------------------------------------------------------------------------------------------------------#
#====================================================================================================================#
    
    # Verif Existance Instance #

if (! grep {/^$inst$/} @horcm_inst_lst) {
    mprint("Instance ${inst} not Find. Exit()", 'e');
}

    ### Vérification Existance (+ Création) Répertoires Backup et Log ###
    
for my $path (($log_path, $backup_path)) {
    if (! -e $path) { system("mkdir $path"); }
}
    
    ### Initialisation du LOGGER ###

my $logger = Logger->init_logger(get_user(), $inst, $log_path);

$logger->log_file_rotate();

    ### Declaration Fonction Signal (^C) ###

$SIG{INT} = sub { mprint(); mprint("Signal Received, Exit()", 'e', '', $logger) };

    ### Entête du Script ###

my ($year, $mon, $day, $hour, $min, $sec) = split(/\s+/, `date "+%Y %m %d %H %M %S"`);

mprint();
mprint("o-> Script Start [Inst:${inst}][Mode:" .uc($mode). "] [${day}/${mon}/${year} ${hour}:${min}:${sec}] <-o");
mprint();

$logger->write_log("INFO", "[START] Script Start / Mode : " .uc($mode));

    ### Recup Info Local/Remote Baie ###
    
my ($local_service, $remote_inst, $remote_service) = get_remote_info($logger, $inst);;

my $local_bay_info = (grep {/;${inst}$/} @BAY_INFO_LST)[0];
my $local_bay_name = (split(';', $local_bay_info))[2];
my $remote_bay_info = (grep {/;${remote_inst}$/} @BAY_INFO_LST)[0];
my $remote_bay_name = (split(';', $remote_bay_info))[2];

    # Verif Instance Start #

my @current_horcm_inst_lst = get_current_instance();
    
if (! grep {/^$inst$/} @current_horcm_inst_lst) {
    set_instance($logger, $inst, 'Start', $horcm_bin_path);
}

    
    #-------------------------------------------------------------------#
    #------------------------ RECUPERATION INFO ------------------------#
    #-------------------------------------------------------------------#
  
my @inst_lst = ($inst);

if ($device =~ /-s/) {   
    
    ### Récupération Infos Host ###
    
    @host_port_lst = get_host_list($logger, $inst, \@srv_name_lst);
    
    ### Vérification Existance Host ###
        
    my @host_not_find_lst = ();

    for (@srv_name_lst) {
        if (! grep {/$_/} @host_port_lst) {
            push(@host_not_find_lst, $_);
        }
    } 
    
    if (@host_not_find_lst) {
        my $srv_not_find = join(',', @host_not_find_lst);
        mprint("Host ${srv_not_find} Not Find. Exit()", 'e', '', $logger);

    }
    
    my $host_info_lst = get_host_info($logger, $inst, \@host_port_lst);
    
    @host_info_lst = @{ $host_info_lst };
    
    ### Récupération Infos Tdev ###
    
    @ldev_lst = get_lun_lst($logger, @host_info_lst);
    
    if (@ldev_lst) {
        @lun_info_lst = get_lun_detail($logger, $inst, \@ldev_lst);
    }
    
} elsif ($device =~ /-l/) {

    @ldev_lst = @ldev_arg_lst;
    @lun_info_lst = get_lun_detail($logger, $inst, \@ldev_lst); 
    
    @host_port_lst = get_column_uniq("4", \@lun_info_lst);
    
    if (@host_port_lst) {
        
        my $host_info_lst = get_host_info($logger, $inst, \@host_port_lst);
        
        @host_info_lst = @{ $host_info_lst };
        
    }
}  

### Récupération Infos Copy Group ###

if (@ldev_lst) {
    
    my ($device_grp_info_lst, $copy_grp_lst) = get_device_grp_detail($logger, $inst, \@ldev_lst);
    
    @device_grp_info_lst = @{ $device_grp_info_lst };
    @copy_grp_lst = @{ $copy_grp_lst };    
}

if (@copy_grp_lst) {
    
    my $reload_instance_check = 0;
    my $inst_return = 0;
    
    my ($cf_check, $backup_file_lst) = set_horcm_conf_file($logger, $inst, $horcm_conf_path, $backup_path, \@copy_grp_lst, \@BAY_INFO_LST);
    
    @backup_file_lst = @{ $backup_file_lst };
    
    if ($cf_check == 1) {
        
        for (($inst, $remote_inst)) {
        
            $inst_return = set_instance($logger, $_, 'Reload', $horcm_bin_path);
            
            if ($inst_return != 0) { $reload_instance_check = 1; }
            
        }
        
        ### Rechargement de l'ancien fichier de config ###
        
        if ($reload_instance_check == 1) {
            restore_conf_file($logger, \@backup_file_lst, $inst, $remote_inst, $horcm_bin_path);
        }
    }
    
    if ($reload_instance_check == 0) {
        @copy_group_info_lst = get_copy_grp_detail($logger, $inst, \@copy_grp_lst, \@BAY_INFO_LST);
    }
}

my @ldev_remote_info_lst = ();
my @lun_remote_info_lst = (); 
my @host_remote_info_lst = ();
 
    ### Récupération Info Remote ###
    
if (@copy_group_info_lst) {
    
    push(@inst_lst, $remote_inst);
    
    my @ldev_remote_lst = ();
    
    if ($device =~ /-l/) {
        
        for (@copy_group_info_lst) {
            
            my ($cg, $dg, $loc_vol, $loc_vol_name, $type, $rmt_vol ,$rmt_bay, $loc_state, $loc_prc) = split(';', $_);
            
            if (grep {/^$rmt_vol$/} @ldev_arg_lst ) {
                push(@ldev_remote_lst, $rmt_vol);
            }
        }
        
    } elsif ($device =~ /-s/) {
        @ldev_remote_lst = get_column_uniq("5", \@copy_group_info_lst);
        
    }
    
    @lun_remote_info_lst = get_lun_detail($logger, $remote_inst, \@ldev_remote_lst);
    
    push(@lun_info_lst, @lun_remote_info_lst); 
    
    my @host_remote_port_lst = get_column_uniq("4", \@lun_remote_info_lst);
    
    if (@host_remote_port_lst) {
        my $host_remote_info_lst = get_host_info($logger, $remote_inst, \@host_remote_port_lst);
        
        @host_remote_info_lst = @{ $host_remote_info_lst };
        
        push(@host_info_lst, @host_remote_info_lst);
        
    }
}
    
    ### Récupération ID Vol Libre ###
    
if ($mode =~ /create/) {
    
    @pool_info_lst = get_pool_info($logger, @inst_lst);
    
    my $ldev_total_count = sum(get_column_uniq("0", \@new_lun_lst));
    my $max_ldev_dec = max(dec_conv(@ldev_lst)) || 1000;
    
    @av_dev_lst = get_available_tdev($logger, \@inst_lst, $max_ldev_dec, $ldev_total_count);
    
}

if ($device =~ /-l/) {
    @srv_name_lst = get_column_uniq("1", \@host_info_lst);
}

    #-------------------------------------------------------------------#
    #------------------------ VERIFICATION INFO ------------------------#
    #-------------------------------------------------------------------#
    
    ### Check si HG temporaire ###
    
if ($mode =~ /remove/ and $total_mode == 0) {
    @hg_tmp_check_lst = check_hg_temp($logger, \@inst_lst, $host_tmp_name, $host_tmp_port);
    
}
   
    ### Check si HG Partagé + Repli ###
    
my $warning_hg = 0;
   
my @lun_repli_lst = ();     
my @tdev_noshare_lst = ();
my @tdev_share_lst = ();

if (@lun_info_lst) {
    
    for my $lun_info (@lun_info_lst) {
        
        my $tdev_share = 0;
        
        my ($i, $tdev, $size, $host, $host_info, $attr, $used_prc, $pool_id, $name) = split(/\;/, $lun_info);
        
        if ($i == $inst) {
        
            my @tdev_host_lst = ();
            
            for ((split(',', $host_info))) {
                push(@tdev_host_lst, (split(':', $_))[0]);
            }
            
            @tdev_host_lst = uniq(@tdev_host_lst);
            
            if ($device =~ /-s/) { 
            
                for (@srv_name_lst) {
                    
                    for my $hg (@tdev_host_lst) {
                        
                        if ($hg !~ /${_}$/) {
                            $warning_hg = 1;
                            $tdev_share = 1;
                        }
                    }
                }
            }
            
            if ($tdev_share == 0) {
                push(@tdev_noshare_lst, "$tdev:$i");
                
            } else {
                push(@tdev_share_lst, "$tdev:$i");
                
            }
            
            if ($attr =~ /HORC/) {
                push(@lun_repli_lst, $tdev);
            } 
            
            @lun_repli_lst = uniq(@lun_repli_lst);
        
        }
    }
}

    ### Check si HG à supprimer (Mode Lun) ###

if (@host_info_lst and $device =~ /-l/) {
    
    for my $hg_info (@host_info_lst) {
        
        my ($grp, $port, $gid, $wwn, $ldev_cnt, $ldev_join, $os_join) = split(';', $hg_info);
        my @hg_ldev_lst = split(',', $ldev_join);
        
        my @hg_ldev_to_rm_lst = ();
        
        for my $hg_ldev (@hg_ldev_lst) {
            
            if (grep {/^${hg_ldev}$/} @ldev_lst) {
                push(@hg_ldev_to_rm_lst, $hg_ldev);
            }
        }
        
        if (scalar(@hg_ldev_lst) == scalar(@hg_ldev_to_rm_lst)) {
            push(@hg_to_rm_lst, $hg_info);
        } 
    }
}

    #----------------------------------------------------------------#
    #------------------------ AFFICHAGE INFO ------------------------#
    #----------------------------------------------------------------#


if (@host_info_lst) {
    display_host_grp_info(\@inst_lst, \@host_info_lst, \@BAY_INFO_LST);
}

if (@copy_grp_lst) {
    display_copy_dev_grp_info(\@inst_lst, \@copy_grp_lst, \@copy_group_info_lst, \@device_grp_info_lst);
}

if (@lun_info_lst) {
    display_lun_info(\@inst_lst, \@lun_info_lst, \@BAY_INFO_LST);
}

if ($mode =~ /create/) {
    display_pool_info(\@inst_lst, \@pool_info_lst, \@BAY_INFO_LST);
}

if ($mode =~ /info/) { s_exit(0, $logger); }

    #------------------------------------------------------------------------------#
    #------------------------ SELECTION INFO (MODE CREATE) ------------------------#
    #------------------------------------------------------------------------------#
    
my @info_choice_lst = ();    
my $dg_cg_choice = '';
my $repli_type_choice = '';

if ($mode =~ /create/) {
    
    ### Selection du Pool ###
    
    my $x = 0;
    
    for my $i (@inst_lst) {
        
        my ($bay_t, $bay_n) = get_bay_info($i, $x, \@BAY_INFO_LST);
        
        my @pool_lst = ();
        
        for (@pool_info_lst) {
            
            my ($pid, $pols, $tp_cap_fmt, $av_cap_fmt, $tl_cap_fmt, $us_prc, $cap_prc, $ldev_cnt, $inst) = split(/\;/, $_);
            
            if ($i == $inst) {
                push(@pool_lst, $pid);
            }
        }
        
        my $pool_choice = '';
        
        while (! grep {/^${pool_choice}$/} @pool_lst) {
            print(". (-) Select Pool on ${bay_t} Bay (${bay_n}) [". join(',', @pool_lst) ."] : ");
            chomp($pool_choice = <STDIN>);
        }
        
        ### Selection du Nom des Devices + Host Group ###
    
        my @host_name_lst = ();
        my @host_lst = ();
        
        my $dev_srv_name_choice = '';
        my $hg_choice = '';
        
        for (@lun_info_lst) {
            my ($ins, $tdev, $size, $host, $host_info, $attr, $used_prc, $pool_id, $name, $type) = split(/\;/, $_);
            
            if ($ins == $i) {
                
                my @host_i_lst = split(',', $host_info);
                
                push(@host_name_lst, (split('_', $name))[0]);
                
                for (@host_i_lst) {
                    my $hg_name = (split(':', $_))[0];
                    push(@host_lst,  $hg_name);
                }
            }
        }
        
        @host_name_lst = uniq(@host_name_lst);
        @host_lst = uniq(@host_lst);
        
        if (scalar(@host_name_lst) > 1) {
            
            while (! grep {/^${dev_srv_name_choice}$/i} @host_name_lst) {
                print(". (-) Select Name for Device on ${bay_t} Bay (${bay_n}) [". join('|', @host_name_lst) ."] : ");
                chomp($dev_srv_name_choice = <STDIN>);
            }
            
        } else {
            $dev_srv_name_choice = $host_name_lst[0];
        
        }
        
        
        if ($x == 0 and @host_lst) {
            
            my @new_host_lst = ();
            
            for my $hg (@host_lst) { 
                for (@srv_name_lst) {
                    if ($hg =~ /${_}$/i) {
                        push(@new_host_lst, $hg);
                    }
                }
            }
            
            @host_lst = @new_host_lst;
            
        }
        
        if (scalar(@host_lst) > 1) {
            
            while (! grep {/^${hg_choice}$/i} @host_lst) {
                print(". (-) Select Host Group for Device on ${bay_t} Bay (${bay_n}) [". join('|', @host_lst) ."] : ");
                chomp($hg_choice = <STDIN>);
            }
        } else {
            $hg_choice = $host_lst[0];
        
        }
        
        push(@info_choice_lst, "$i;$pool_choice;$dev_srv_name_choice;$hg_choice");
        
        mprint();
        
        $x += 1;  
        
    }
    
    ### Selection du Sens de Réplication + DG/CG ###
    
    if (@copy_group_info_lst) {
        
        ## CG  ##
        
        my $dg_choice = '';
        my @dg_lst = get_column_uniq("1", \@copy_group_info_lst);
        
        if (scalar(@dg_lst) > 1) {
            
            while (! grep {/^${dg_choice}$/i} @dg_lst) {
                print(". (-) Select DG on Local Bay (${local_bay_name}) [". join('|', @dg_lst) ."] : ");
                chomp($dg_choice = <STDIN>);
            }
            
        } else {
            $dg_choice = $dg_lst[0];
        }
        
        ## Sens de Réplication ##
        
        my @rep_type_lst = ();
        
        for (@copy_group_info_lst) {
            
            my ($cgrp, $dgrp, $ldev, $ldev_name, $type, $rdev, $rbay, $state, $prc) = split(';', $_);
             
            if ($dgrp =~ /^${dg_choice}$/) {
                $dg_cg_choice = "$dg_choice:$cgrp";
                push(@rep_type_lst, $type);
            }
        }
        
        @rep_type_lst = uniq(@rep_type_lst);
        
        if (scalar(@rep_type_lst) > 1) {
        
            while ($repli_type_choice !~ /^(L(ocal)?|R(emote)?)$/i) {
                print(". (-) Select Replication Type on Local Bay (${local_bay_name}) [L(ocal)|R(emote)] : ");
                chomp($repli_type_choice = <STDIN>);
            }
            
            if ($repli_type_choice =~ /L(ocal)?/i) { $repli_type_choice = 'Local'; } else { $repli_type_choice = 'Remote'; }
        
        } else {
            $repli_type_choice = $rep_type_lst[0];
        }
    }
    
    ### Affichage Informations Selectionnées ###
    
    if (@copy_group_info_lst) {
        
        my ($dg, $cg) = split(':', $dg_cg_choice);
        
        mprint();
        mprint("(o) Dev.G -> Copy.G [R.Type] : ${dg} -> ${cg} [${repli_type_choice}]");
        mprint();
        
        $logger->write_log("INFO", "[REPLI] DG:$dg, CG:$cg, REPLI.T:$repli_type_choice");
    }
    
    $x = 0;
    
    for my $i (@inst_lst) {
        
        my ($i, $pool_choice, $dev_srv_name_choice, $hg_choice) = split(';', $info_choice_lst[$x]);
        
        my ($bay_t, $bay_n) = get_bay_info($i, $x, \@BAY_INFO_LST);
        
        mprint("$bay_t Informations ($i, $bay_n)", 's3');
        mprint("Pool\t\t: $pool_choice");
        mprint("Dev Name\t: $dev_srv_name_choice");
        mprint("HG Name\t: $hg_choice");
        mprint();
        
        $logger->write_log("INFO", "[NEW LUN] I:$i, Pool:$pool_choice, Dev.Name:$dev_srv_name_choice, HG:$hg_choice");
        
        $x += 1; 
    }
}

    #-------------------------------------------------------#
    #------------------------ ERROR ------------------------#
    #-------------------------------------------------------#

if ($mode =~ /remove/) {
    
    if (@copy_grp_lst and @lun_repli_lst and ! @copy_group_info_lst) {
        mprint("Lun(s) With Active Replication, Script can't Delete it (No Access to Copy Group) [". join(',', @lun_repli_lst) ."]", 'e');
    }
}

    #----------------------------------------------------------------------#
    #------------------------ GENERATION COMMANDES ------------------------#
    #----------------------------------------------------------------------#
    
for my $m (("D", "X")) {
    
    my $cmd_mode_display = 'To Execute';
    
    if ($m =~ /X/) { my $cmd_mode_display = 'Execution Start'; }
    
    mprint();
    mprint();
    mprint("Command(s) ${cmd_mode_display}", 's1');
    mprint();
    
    if ($mode =~ /remove/) {
        
        my $x = 0;
        
        my @rmv_inst_lst = ($inst);
        
        for my $i (@rmv_inst_lst) {
            
            my ($bay_t, $bay_n) = get_bay_info($i, $x, \@BAY_INFO_LST);
            
            ### Remove Réplication ###
            
            if (@copy_group_info_lst and @tdev_noshare_lst) {
                
                my @dg_lst = get_column_uniq("1", \@copy_group_info_lst);
                
                for my $dg (@dg_lst) {
                    
                    my @dev_to_delete = ();
                    
                    for (@copy_group_info_lst) {
                        my ($cgrp, $dgrp, $ldev, $ldev_name, $type, $rdev, $rbay, $state, $prc) = split(';', $_);
                        
                        if ($dgrp =~ /^${dg}$/ and grep {/^${ldev}:/} @tdev_noshare_lst and $state !~ /SIMPL/) {
                            push(@dev_to_delete, "$ldev:$ldev_name");
                        }
                    }
                    
                    if (@dev_to_delete) {
                    
                        my $cg_info = (grep {/;${dg};/} @copy_grp_lst)[0];
                        my ($cgroup, $dgroup, $sn, $dev_cnt) = split(';', $cg_info);
                        
                        if ($x == 0) {
                        
                            if ($dev_cnt == scalar(@dev_to_delete)) {
                                
                                mprint("Remove Replication By Copy.Grp [${cgroup}] on $bay_t Bay ($bay_n)", 's2');
                                
                                cmd_exec($m, "pairsplit -g ${cgroup} -S -I${inst}", $logger);
                            
                            } else {
                                
                                mprint("Remove Replication By T.Dev [${cgroup}] on $bay_t Bay ($bay_n)", 's2');
                                
                                for (@dev_to_delete) {
                                    my ($t, $n) = split(':', $_);
                                    cmd_exec($m, "pairsplit -g ${cgroup} -d ${n} -S -I${inst}", $logger);
                                }
                            }
                            
                            mprint();
                            
                        }
                        
                        mprint("Remove Lun(s) to Dev.Group [${dgroup}] on $bay_t Bay ($bay_n)", 's2');
                        
                        for (@dev_to_delete) {
                            my ($t, $n) = split(':', $_);
                            cmd_exec($m, "raidcom delete device_grp -device_grp_name ${dgroup} -ldev_id 0x${t} -fx -I${i}", $logger)
                        }
                        
                        mprint();
                    }
                }   
            }
            
            if (@copy_grp_lst and @tdev_noshare_lst and ! @lun_repli_lst and ! @copy_group_info_lst) {
                
                my @dg_lst = get_column_uniq("1", \@copy_grp_lst);
                
                for my $dg (@dg_lst) {
                    
                    my @dev_to_delete = ();
                    
                    my $cg_info = (grep {/;${dg};/} @copy_grp_lst)[0];
                    my ($cgroup, $dgroup, $sn, $dev_cnt) = split(';', $cg_info);
                    
                    mprint("Remove Lun(s) to Dev.Group [${dgroup}] on $bay_t Bay ($bay_n)", 's2');
                    
                    for (@device_grp_info_lst) {
                        my ($cgrp, $dgrp, $ldev, $ldev_name) = split(';', $_);
                        
                        if ($dgrp =~ /^${dg}$/ and grep {/^${ldev}:/} @tdev_noshare_lst) {
                            push(@dev_to_delete, "$ldev:$ldev_name");
                        }
                    }
                    
                    for (@dev_to_delete) {
                        my ($t, $n) = split(':', $_);
                        cmd_exec($m, "raidcom delete device_grp -device_grp_name ${dgroup} -ldev_id 0x${t} -fx -I${i}", $logger)
                    }
                    
                    mprint();
                }
            }
            
            
            ### Dé-Mappage des Luns ###
            
            if (@lun_info_lst and @host_info_lst) {
                
                mprint("Unmap Lun(s) on $bay_t Bay ($bay_n)", 's2');
                
                for my $lun_info (@lun_info_lst) {
                    
                    my ($inst, $tdev, $size, $host, $host_info, $attr, $used_prc) = split(/\;/, $lun_info);
                    
                    if ($inst == $i) {
                    
                        my @host_i_lst = split(',', $host_info);
                        
                        for (@host_i_lst) {
                            
                            my ($hst_grp, $port, $gid) = split(':', $_);
                            
                            for (@srv_name_lst) {
                                
                                if ($hst_grp =~ /$_/) {
                                    cmd_exec($m, "raidcom delete lun -port ${port} ${hst_grp} -ldev_id 0x${tdev} -fx -I${i}", $logger)
                                }
                            }
                        }
                    }
                }
                
                mprint();
                
            }
            
            ### Delete des Host Group ###
            
            if ($device =~ /-l/ and @hg_to_rm_lst) {
                @host_info_lst = @hg_to_rm_lst;
            }
            
            if (@host_info_lst) {
            
                mprint("Delete Host(s) Group on $bay_t Bay ($bay_n)", 's2');
                
                for my $host_info (@host_info_lst) {
                    
                    my ($inst, $hst, $port, $gid, $wwn, $dev_cnt, $dev_fmt, $os) = split(/\;/, $host_info);
                    
                    if ($inst == $i) {
                        cmd_exec($m, "raidcom delete host_grp -port ${port} ${hst} -fx -I${i}", $logger);
                    }
                }
                
                mprint();
            
            }
            
            ### Delete des Luns ###
            
            if (@tdev_noshare_lst) {
            
                if ($total_mode == 1) {
            
                    mprint("Delete Lun(s) on $bay_t Bay ($bay_n)", 's2');
                    
                    for (@tdev_noshare_lst) {
                        my ($l, $inst) = split(':', $_);
                        
                        if ($inst == $i) {
                            cmd_exec($m, "raidcom delete ldev -ldev_id 0x${l} -I${i}", $logger);
                        }
                    }
                    
                    mprint();
                    
                } else {
                    
                    my $host_tmp_exist_check = (split(';', $hg_tmp_check_lst[$x]))[1];
                    
                    if ($host_tmp_exist_check == 0) {
                        
                        mprint(" Create H.Grp Temp on $bay_t Bay ($bay_n)", 's2');
                        cmd_exec($m, "raidcom add host_grp -port ${host_tmp_port}-${host_tmp_gid} -host_grp_name ${host_tmp_name} -I${i}", $logger);
                        mprint();
                    
                    }
                    
                    mprint("Add Lun(s) to H.Grp Temp [${host_tmp_name}] on $bay_t Bay ($bay_n)", 's2');
                    
                    for (@tdev_noshare_lst) {
                        
                        my ($l, $inst) = split(':', $_);
                        
                        if ($inst == $i) {
                            cmd_exec($m, "raidcom add lun -port ${host_tmp_port} ${host_tmp_name} -ldev_id 0x${l} -fx -I${i}", $logger);
                        }
                    }
                    
                    mprint();
                    
                }
            }
            
            $x += 1;
        }
        
        if (@copy_group_info_lst and @tdev_noshare_lst) {
            
            if ($m =~ /D/) {
                mprint(" () Restore Config File");
                
            } elsif ($m =~ /X/) {
                restore_conf_file(\@backup_file_lst, $inst, $remote_inst, $horcm_bin_path);
            }
        }
        
    } elsif ($mode =~ /create/) {
        
        my $x = 0;
        
        for my $i (@inst_lst) {
            
            my $bay_t = 'Local';
            my $bay_n = $local_bay_name;
            my $rep_type = '';
            
            my ($ins, $pool_choice, $dev_srv_name_choice, $hg_choice) = split(';', $info_choice_lst[$x]);
            
            if ($x == 0) {
                if ($repli_type_choice =~ /Local/) { $rep_type = "R1"; } else { $rep_type = "R2"; }
            
            } else {
                $bay_t = 'Remote';
                $bay_n = $remote_bay_name;
                
                if ($repli_type_choice =~ /Local/) { $rep_type = "R2"; } else { $rep_type = "R1"; }
                
            }
            
            ### Creation des Tdev ###
            
            mprint("Create T.Dev on ${bay_t} Bay [${bay_n}]", 's2');
            
            my $y = 0;
            
            for my $nl (@new_lun_lst) {
                
                my ($count, $val_gb, $val_bk) = split(';', $nl); 
                
                for (my $w = 1; $w <= $count; $w++) {
                    my $new_dev = "0x$av_dev_lst[$y]";
                    
                    cmd_exec($m, "raidcom add ldev -pool ${pool_choice} -ldev_id ${new_dev} -capacity ${val_bk} -I${i}", $logger);
                    
                    $y += 1;
                } 
            }
            
            mprint();
            
            if ($m =~ /X/) { sleep(10); };
            
            ### Rename des Tdev ###
            
            mprint("Rename T.Dev on ${bay_t} Bay [${bay_n}]", 's2');
            
            for my $av (@av_dev_lst) {
                
                my $dev_naming = $dev_srv_name_choice. "_" .uc($av);
                
                if ($rep_type) { $dev_naming = $dev_naming. "_" .$rep_type; }
                
                cmd_exec($m, "raidcom modify ldev -ldev_id 0x${av} -ldev_name ${dev_naming} -I${i}", $logger);
                
            }
            
            mprint();
            
            ### Ajouts des Tdev dans le HG ###
            
            mprint("Add T.Dev in HG on ${bay_t} Bay [${bay_n}]", 's2');
            
            for my $av (@av_dev_lst) {
                
                for my $hg (@host_info_lst) {
                    my ($ins, $hst, $port, $gid, $wwn, $dev_cnt, $dev_fmt, $os) = split(/\;/, $hg);
                    
                    if ($ins == $i and $hst =~ /^$hg_choice$/) {
                        cmd_exec($m, "raidcom add lun -port ${port} ${hst} -ldev_id 0x${av} -I${i}", $logger);
                    }
                }
            }
            
            mprint();
            
            if (@copy_group_info_lst) {
            
                ### Ajouts des Tdev dans le DG ###
                
                my ($dg_choice, $cg_choice) = split(':', $dg_cg_choice);
                my $z = 0;
                
                if ($repli_type_choice =~ /Remote/) { $z = 1; }
                
                my ($ins, $pool_choice, $dev_srv_name_choice, $hg_choice) = split(';', $info_choice_lst[$z]);
                
                mprint("Add T.Dev in DG on ${bay_t} Bay [${bay_n}]", 's2');
                
                for my $av (@av_dev_lst) {
                    
                    my $dev_naming = $dev_srv_name_choice. "_" .uc($av);
                    
                    cmd_exec($m, "raidcom add device_grp -device_grp_name ${dg_choice} ${dev_naming} -ldev_id 0x${av} -I${i}", $logger);
                
                }
                
                mprint();
            
            }
            
            $x += 1;
            
        }
        
        
        if (@copy_group_info_lst) {
            
            ### Redémarrage de l'instance ###
            
            if ($m =~ /D/) {
                mprint(" () Reload Instance");
                
            } elsif ($m =~ /X/) {
                
                for my $i (@inst_lst) {
                
                    my $inst_return = set_instance($logger, $i, 'Reload', $horcm_bin_path);
                    
                    if ($inst_return != 0) {
                        mprint('Problem with Instance Reload', 'e', '', $logger);
                    }
                    
                }
            }
            
            mprint();
            
            ### Creation de l'appairage ###
            
            my ($i, $x, $rep_arg) = ($inst_lst[0], 0, 'l');
            
            if ($repli_type_choice =~ /Remote/) {
                $rep_arg = 'r';
            }
            
            my ($bay_t, $bay_n) = get_bay_info($i, $x, \@BAY_INFO_LST);
            my ($ins, $pool_choice, $dev_srv_name_choice, $hg_choice) = split(';', $info_choice_lst[$x]);
            my ($dg_choice, $cg_choice) = split(':', $dg_cg_choice);
            
            mprint("Create T.Dev Pairing (Mode : ${repli_type_choice}) on ${bay_t} Bay [${bay_n}]", 's2');
            
            for my $av (@av_dev_lst) {
                
                my $dev_naming = $dev_srv_name_choice. "_" .uc($av);
                
                cmd_exec($m, "paircreate -g ${cg_choice} -d ${dev_naming} -f never -v${rep_arg} -I${i}", $logger);
            }
            
            mprint();
            
        }
        
    }
    
    #---------------------------------------------------------#
    #------------------------ WARNING ------------------------#
    #---------------------------------------------------------#
        
    if ($m =~ /D/) {
        
        if ($mode =~ /remove/) {
        
            if ($warning_hg == 1) {
            
                my @lun_share_lst = get_column_uniq("1", @tdev_share_lst);
                
                mprint("Lun(s) With Host Group Shared [". join(',', @lun_share_lst) ."]. Script Not Delete It", 'w');
            }
            
            if (@lun_repli_lst) {
                mprint("Lun(s) With Active Replication [". join(',', @lun_repli_lst) ."]. Script Delete It (For Lun(s) to Remove Only)", 'w');
            
            }
            
            if ($device =~ /-l/ and @hg_to_rm_lst) {
                my $host_join = join(',', get_column_uniq("0", \@hg_to_rm_lst));
                
                mprint("All Luns of HG(s) [". ${host_join} ."] Will be Remove. So HG will be Delete Too", 'w');
            }
            
            mprint();
        
        }
    }
    
    #-----------------------------------------------------------------------#
    #------------------------ CHOIX AVANT EXECUTION ------------------------#        
    #-----------------------------------------------------------------------#   
        
        
    if ($m =~ /D/) {
        
        my $response = '';
        
        while ($response !~ /^(Y|YES|N|NO)$/) {
            print(". <> Do You Want Execute Command [y|n] ? ");
            chomp($response = <STDIN>);
            $response = uc($response);
        }
        
        if ($response =~ /Y/) {
            next;
            
        } else {
            $logger->write_log("INFO", "[END BY USER] Script End by User (No Response) / Mode : " .uc($mode));
            last;
        }  
    }
}

s_exit(0, $logger);

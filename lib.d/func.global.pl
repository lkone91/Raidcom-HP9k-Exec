use strict;


    #---------------------------------------------------------------------#
    #------------------------ FONCTIONS AFFICHAGE ------------------------#
    #---------------------------------------------------------------------#

my $marge = '. ';

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

sub count {
    my %counts;
    $counts{$_}++ for @_;
    
    return %counts;
}

sub get_column_uniq { #Arg $column @list $unique 
    
    my ($column, $l, $unique) = @_;
    my @list = @{ $l };
    
    my @new_lst = ();
    
    for (@list) {
        push(@new_lst, (split(";", $_))[int($column)]);
    }
    
    @new_lst = split(',', join(',', @new_lst));
    
    if (! $unique) {
        return uniq(@new_lst);
    } else {
        return @new_lst;
    }
}

sub mprint {
    
    my ($text, $mode, $end, $logger) = @_;
    
    if (! $mode) { $mode = 't'; }
    if (! $end) { $end = "\n"; }
    
    if ($mode =~ /t/) {
        print("${marge}${text}${end}");
        
    } elsif ($mode =~ /s1/) {
        my $line = "." x 70;
        
        print("${marge}${text}\n");
        print("${line}${end}");    
        
    } elsif ($mode =~ /s2/) {
        my $line = "~" x length(${text});
        
        print("${marge} <> ${text}\n");
        print("${marge}    ${line}${end}");
       
    } elsif ($mode =~ /s3/) {
        my $line = "-" x length(${text});
        
        print("${marge}${text}\n");
        print("${marge}${line}${end}");
       
    } elsif ($mode =~ /i/) {
        print("${marge}\n");
        print("${marge} \033[7m <> ${text} \033[0m${end}");
       
    } elsif ($mode =~ /w/) {
        print("${marge}\n");
        print("${marge} \033[30m\033[43m <!> Warning : ${text} \033[0m${end}");
        
        if ($logger) {
            $logger->write_log("WARNING", $text);
        }
        
    } elsif ($mode =~ /e/) {
        print("${marge}\n");
        print("${marge} \033[33m\033[41m <!> Error : ${text} \033[0m${end}");
        
        if ($logger) {
            $logger->write_log("ERROR", $text);
        }
        
        s_exit(1, $logger);
        
    }
        
}

sub table_display { #Arg $title @array @index $space
    
    my $title = shift;
    my $array = shift;
    my $index = shift;
    my $space = shift || 1;
    
    my @array = @{ $array };
    my @index = @{ $index };
    
    my @new_index = ();
    my @new_array = ();
    
    $space = " " x $space;
    
    for my $i (@index) {    
        
        my $max_i = 0;
        
        my @title_lst = split(';', $title);
        my @title_line_lst = ();
        
        for (@title_lst) {
            push(@title_line_lst, "-" x length($_));
        }
        
        @new_array = ($title, join(';', @title_line_lst));
        push(@new_array, @array);
        
        for my $l (@new_array) {
            
            my @line_lst = split(';', $l);
        
            if (length($line_lst[$i]) >= $max_i) {
                $max_i = length($line_lst[$i]);
            }
        }
        
        push(@new_index, "$i:$max_i");
        
    }

    for my $l (@new_array) {
        
        my @line_lst = split(';', $l);
        
        print(".  ");
        
        for my $i (@new_index) {
            
            my ($idx, $max) = split(':', $i);
            
            $max = int($max);
            
            printf("%-${max}s${space}", "$line_lst[$idx]");
        }
        
        print("\n");

    }
}

    #---------------------------------------------------------------------#
    #------------------------ FONCTIONS EXECUTION ------------------------#
    #---------------------------------------------------------------------#

sub cmd_retrieve { #Arg $cmd $logger

    my ($cmd, $logger) = @_;
    
    my @cmd_lst = split('\n', `$cmd 2>&-`);
    
    if ($logger) {
        $logger->write_log("INFO", "[CMD:R] $cmd");
    }
    
    return @cmd_lst;

}

    
sub cmd_exec {
    
    my ($mode, $cmd, $logger) = @_;
    
    my $return_cmd = 0;
    my $return_err_msg = '';
    
    if ($mode =~ /D/) {
        mprint(" ${cmd}");
        
    } elsif ($mode =~ /X/) {
        
        my ($year, $mon, $day, $hour, $min, $sec) = split(/\s+/, `date "+%Y %m %d %H %M %S"`);
        
        print(". [$hour:$min:$sec] ${cmd} ");
        
        if ($logger) { 
            $logger->write_log("INFO", "[CMD:X] $cmd");
        }
        
        $return_cmd = system("${cmd} > /dev/null 2>&1");
        
        $return_err_msg = $!;
        
        if ($return_cmd != 0) {
            print("[cmd Error]\n");
            mprint("Command Error : $return_err_msg", 'e', '', $logger);
            
        } else {
            print("[cmd OK]\n");
            
        }
    }
    

}

sub s_exit { #Arg $return_code $logger
    
    my ($return_code, $logger) = @_;
    
    my ($year, $mon, $day, $hour, $min, $sec) = split(/\s+/, `date "+%Y %m %d %H %M %S"`);
    
    mprint();
    
    if (int($return_code) != 0) {
        mprint("o-> Script Stop [ERR:${return_code}] [${day}/${mon}/${year} ${hour}:${min}:${sec}] <-o");
        
        if ($logger) {
            $logger->write_log("ERROR", "[STOP] Script Stop [ERR CODE:${return_code}]");
        }
        
    } else {
        mprint("o-> Script End [${day}/${mon}/${year} ${hour}:${min}:${sec}] <-o");
        
        if ($logger) {
            $logger->write_log("INFO", "[END] Script End");
        }
    }

    mprint();
    exit($return_code);
    
}


    #----------------------------------------------------------------------#
    #------------------------ FONCTIONS CONVERTION ------------------------#
    #----------------------------------------------------------------------#

sub size_conv { #Arg $size, $type, $round, $round_cmd
    
    my $size = int(shift);
    my $type = shift;
    my $round = shift || undef;
    my $round_dcm = shift || 1;
    
    my $result = '';
    
    if ($type =~ /BK/) { if ($size >= 2) { $size = $size/2; $type = 'KB'; } }
    if ($type =~ /KB/) { if ($size >= 1024) { $size = $size/1024; $type = 'MB'; } }
    if ($type =~ /MB/) { if ($size >= 1024) { $size = $size/1024; $type = 'GB'; } }
    if ($type =~ /GB/) { if ($size >= 1024) { $size = $size/1024; $type = 'TB'; } }
    
    if ($round) {
        $size = sprintf("%.${round_dcm}f", $size);
    } else {
        $size = int($size);
    }
    
    $result = "$size $type";
    
    return $result;
} 

sub dec_conv { #Arg @hex_lst
    
    my (@hex_lst) = @_;
    my @dec_lst = ();
    
    for (@hex_lst) {
        push(@dec_lst, hex($_));
    }
    
    return @dec_lst;
    
}

1;

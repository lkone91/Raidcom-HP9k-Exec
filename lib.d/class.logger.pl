use strict;
    
    #---------------------------------------------------------------#
    #------------------------ CLASSE LOGGER ------------------------#
    #---------------------------------------------------------------#

package Logger;

sub init_logger {
    
    my ($log_cls, $user, $inst, $log_path) = @_;
    
    my $log_file = "${log_path}/log_hp9k_exec.log";
    
    my $this = {
        "user" => uc($user),
        "inst" => $inst,
        "session_id" => substr(rand(10), 2, 6),
        "log_file" => $log_file
    };
    
    bless($this, $log_cls);
    return $this;
}

sub log_file_rotate {
    
    my ($this) = @_;
    
    my $file_size = (stat($this->{log_file}))[7];
    
    if ($file_size >= 2097152) { #2MB
    
        my ($year, $mon, $day, $hour, $min, $sec) = split(/\s+/, `date "+%Y %m %d %H %M %S"`);
        
        my $bck_log_file = "$this->{log_file}.${year}${mon}${day}_${hour}${min}${sec}";
        
        rename("$this->{log_file}", $bck_log_file) or die "Can't Move Log file: $!";
        
    }
}

sub write_log {
    
    my ($this, $level, $message) = @_;
    
    my ($year, $mon, $day, $hour, $min, $sec) = split(/\s+/, `date "+%Y %m %d %H %M %S"`);
    
    open(my $out, '>>', $this->{log_file}) or die "Can't write Log file: $!";
    
    print ($out "[${year}/${mon}/${day} ${hour}:${min}:${sec} ID:$this->{session_id} U:$this->{user} I:$this->{inst}] $level : $message\n");
    
}

1;

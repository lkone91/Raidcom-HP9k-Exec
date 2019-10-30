# Raidcom HP9K-Utils

## Information

The `hp9k_utils.pl` script is coded in Perl5, runs on AIX/Linux and requires `raidcom` package.

Package `perl-Data-Dumper.x86_64` is also mandatory.

The script only works on `HP9500` array instances in the `hp9k_utils.pl` script body :

```perl
my @BAY_INFO_LST = (
    "localhost;30000;HP_BAY_1;82500;86",  
    "localhost;30001;HP_BAY_2;82501;87",  
);
```

Script provide following feature :
 * Audit (By Volume or Host)
 * Deletion (By Volume or Host)
 * Creation (Of Volume)

You can get all command and few examples, with `-help` or `-h` option.


## Operation

Here are some examples of use in situation.

By default all mode except info work on `dry-run`. That is, the user must validate to execute the commands (Yes/No).

### Audit

See an example with a server audit.

```
$ ./hp9k_utils.pl -i 001 info -s HOST2
.
. o-> Script Start [Inst:001][Mode:INFO] [26/10/2017 15:54:19] <-o
.
.  Retrieving HG List (001)         [done]
.  Retrieving HG Info (001)         [done]
.  Retrieving Lun Info (001)        [done]
.  Retrieving DG Info (001)         [done]
.  Backup Conf Files (001, 002)     [done]
.  Check Local Conf File (001)      [done]
.  Check Remote Conf File (002)     [done]
.  Retrieving CG Info (001)         [done]
.  Retrieving Lun Info (002)        [done]
.  Retrieving HG Info (002)         [done]
.
. [001, 002] Host Group Informations
......................................................................
.
.  <> Local Bay (ARRAY_A) [I:001]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~
.
. Host Group Name : HG_HOST2
.
.  Port  GID OS  Dev Login
.  ----  --- --  --- -----
.  CL7-G 002  AIX 17  1000000000000000,1000000000000001
.  CL7-Q 002  AIX 17  1000000000000002,1000000000000003
.  CL8-G 002  AIX 17  1000000000000004,1000000000000005
.  CL8-Q 002  AIX 17  1000000000000006,1000000000000007
.
.  <> Remote Bay (ARRAY_B) [I:002]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~
.
. Host Group Name : HG_HOST1
.
.  Port  GID OS  Dev Login
.  ----  --- --  --- -----
.  CL7-G 11  AIX 18  1000000000000020,1000000000000021
.  CL8-Q 11  AIX 18  1000000000000022,1000000000000023
.  CL8-G 11  AIX 18  1000000000000024,1000000000000025
.  CL7-Q 11  AIX 18  1000000000000026,1000000000000027
.
.
. [001, 002] Copy Group Informations
......................................................................
.
.  <> CG_HOST1_APP1 [DG:DG_HOST1_APP1, D.Nb:6]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.
.  L.Dev Name          Type   R.Dev R.Bay(SN)      State Prc
.  ----- ----          ----   ----- ---------      ----- ---
.  3afc  HOST1_3AFC Remote 3afc  ARRAY_B(86580) PAIR  100%
.  3afd  HOST1_3AFD Remote 3afd  ARRAY_B(86580) PAIR  100%
.  3afe  HOST1_3AFE Remote 3afe  ARRAY_B(86580) PAIR  100%
[...]
.
.  <> CG_HOST2_APP2 [DG:DG_HOST2_APP2, D.Nb:7]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.
.  L.Dev Name       Type  R.Dev R.Bay(SN)      State Prc
.  ----- ----       ----  ----- ---------      ----- ---
.  3b01  HOST2_3B01 Local 3b01  ARRAY_B(86580) PSUS  99%
.  3b02  HOST2_3B02 Local 3b02  ARRAY_B(86580) PSUS  98%
.  3b03  HOST2_3B03 Local 3b03  ARRAY_B(86580) PSUS  37%
[...]
.
. [001, 002] TDev Informations
......................................................................
.
.  <> Local Bay (ARRAY_A) [I:001]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~
.
. Total Size    : 862GB
. Total Lun     : 17
. Lun by Type   : 1x136 GB,1x46 MB,10x34 GB,5x68 GB
.
.  Tdev Name          Size   Used Pool Attr         Host Group
.  ---- ----          ----   ---- ---- ----         ----------
.  3afc HOST1_3AFC_R2 34 GB  73%  6    CVS|HORC|THP HG_HOST2[7G002:2|7Q002:2|8G002:2|8Q002:2](4)
.  3afd HOST1_3AFD_R2 34 GB  99%  6    CVS|HORC|THP HG_HOST2[7G002:3|7Q002:3|8G002:3|8Q002:3](4)
.  3afe HOST1_3AFE_R2 34 GB  44%  6    CVS|HORC|THP HG_HOST2[7G002:4|7Q002:4|8G002:4|8Q002:4](4)
[...]
.
.  <> Remote Bay (ARRAY_B) [I:002]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~
.
. Total Size    : 816GB
. Total Lun     : 16
. Lun by Type   : 1x136 GB,10x34 GB,5x68 GB
.
.  Tdev Name          Size   Used Pool Attr         Host Group
.  ---- ----          ----   ---- ---- ----         ----------
.  3afc HOST1_3AFC_R1 34 GB  73%  6    CVS|HORC|THP HG_HOST1[7G11:3|7Q11:3|8G11:3|8Q11:3](4)
.  3afd HOST1_3AFD_R1 34 GB  99%  6    CVS|HORC|THP HG_HOST1[7G11:4|7Q11:4|8G11:4|8Q11:4](4)
.  3afe HOST1_3AFE_R1 34 GB  44%  6    CVS|HORC|THP HG_HOST1[7G11:5|7Q11:5|8G11:5|8Q11:5](4)
[...]
.
.
. o-> Script End [26/10/2017 15:55:42] <-o
.
```


### Deletion

See an example with a server delete.

```
$ ./hp9k_utils.pl -i 001 delete -s HOST1
.
. o-> Script Start [Inst:001][Mode:REMOVE] [26/10/2017 17:55:02] <-o
.
.  Retrieving HG List (001)         [done]
.  Retrieving HG Info (001)         [done]
.  Retrieving Lun Info (001)        [done]
.  Retrieving DG Info (001)         [done]
.  Backup Conf Files (001, 002)     [done]
.  Check Local Conf File (001)      [done]
.  Check Remote Conf File (002)     [done]
.  Retrieving CG Info (001)         [done]
.  Retrieving Lun Info (002)        [done]
.  Retrieving HG Info (002)         [done]
.
. [001, 002] Host Group Informations
......................................................................
.
.  <> Local Bay (ARRAY_A) [I:001]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~
.
. Host Group Name : HG_HOST1
.
.  Port  GID OS  Dev Login
.  ----  --- --  --- -----
.  CL7-G 002  AIX 17  c000000000000000,c000000000000001
.  CL7-Q 002  AIX 17  c000000000000002,c000000000000003
.  CL8-G 002  AIX 17  c000000000000004,c000000000000005
.  CL8-Q 002  AIX 17  c000000000000006,c000000000000007
.
.  <> Remote Bay (ARRAY_B) [I:002]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~
.
. Host Group Name : HG_HOST2
.
.  Port  GID OS  Dev Login
.  ----  --- --  --- -----
.  CL7-G 11  AIX 18  c000000000000020,c000000000000021
.  CL8-Q 11  AIX 18  c000000000000022,c000000000000023
.  CL8-G 11  AIX 18  c000000000000024,c000000000000025
.  CL7-Q 11  AIX 18  c000000000000026,c000000000000027
.
.
. [001, 002] Copy Group Informations
......................................................................
.
.  <> CG_HOST2_APP1 [DG:DG_HOST2_APP1, D.Nb:6]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.
.  L.Dev Name       Type   R.Dev R.Bay(SN)      State Prc
.  ----- ----       ----   ----- ---------      ----- ---
.  3afc  HOST2_3AFC Remote 3afc  ARRAY_B(86580) PAIR  100%
.  3afd  HOST2_3AFD Remote 3afd  ARRAY_B(86580) PAIR  100%
.  3afe  HOST2_3AFE Remote 3afe  ARRAY_B(86580) PAIR  100%
.  3aff  HOST2_3AFF Remote 3aff  ARRAY_B(86580) PAIR  100%
.  3b00  HOST2_3B00 Remote 3b00  ARRAY_B(86580) PAIR  100%
.  3b2f  HOST2_3B2F Remote 3b2f  ARRAY_B(86580) PAIR  100%
.
.  <> CG_HOST1_ROOT [DG:DG_HOST1_ROOT, D.Nb:3]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.
.  L.Dev Name       Type  R.Dev R.Bay(SN)      State Prc
.  ----- ----       ----  ----- ---------      ----- ---
.  3afb  HOST1_3AFB Local 3afb  ARRAY_B(86580) PAIR  100%
.  3b6e  HOST1_3B6E Local 3b6e  ARRAY_B(86580) PAIR  100%
.  3ea5  HOST1_3EA5 Local 3ea5  ARRAY_B(86580) PAIR  100%
.
.  <> CG_HOST1_APP2 [DG:DG_HOST1_APP2, D.Nb:7]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.
.  L.Dev Name       Type  R.Dev R.Bay(SN)      State Prc
.  ----- ----       ----  ----- ---------      ----- ---
.  3b01  HOST1_3B01 Local 3b01  ARRAY_B(86580) PSUS  99%
.  3b02  HOST1_3B02 Local 3b02  ARRAY_B(86580) PSUS  98%
.  3b03  HOST1_3B03 Local 3b03  ARRAY_B(86580) PSUS  37%
.  3b04  HOST1_3B04 Local 3b04  ARRAY_B(86580) PSUS  89%
.  3b05  HOST1_3B05 Local 3b05  ARRAY_B(86580) PSUS  99%
.  3b2e  HOST1_3B2E Local 3b2e  ARRAY_B(86580) PSUS  100%
.  3b30  HOST1_3B30 Local 3b30  ARRAY_B(86580) PAIR  100%
.
. [001, 002] TDev Informations
......................................................................
.
.  <> Local Bay (ARRAY_A) [I:001]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~
.
. Total Size    : 862GB
. Total Lun     : 17
. Lun by Type   : 1x136 GB,1x46 MB,10x34 GB,5x68 GB
.
.  Tdev Name          Size   Used Pool Attr         Host Group
.  ---- ----          ----   ---- ---- ----         ----------
.  3afc HOST2_3AFC_R2 34 GB  73%  6    CVS|HORC|THP HG_HOST1[7G002:2|7Q002:2|8G002:2|8Q002:2](4)
.  3afd HOST2_3AFD_R2 34 GB  99%  6    CVS|HORC|THP HG_HOST1[7G002:3|7Q002:3|8G002:3|8Q002:3](4)
.  3afe HOST2_3AFE_R2 34 GB  44%  6    CVS|HORC|THP HG_HOST1[7G002:4|7Q002:4|8G002:4|8Q002:4](4)
.  3aff HOST2_3AFF_R2 34 GB  40%  6    CVS|HORC|THP HG_HOST1[7G002:5|7Q002:5|8G002:5|8Q002:5](4)
.  3b00 HOST2_3B00_R2 34 GB  51%  6    CVS|HORC|THP HG_HOST1[7G002:6|7Q002:6|8G002:6|8Q002:6](4)
[...]
.
.  <> Remote Bay (ARRAY_B) [I:002]
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~
.
. Total Size    : 816GB
. Total Lun     : 16
. Lun by Type   : 1x136 GB,10x34 GB,5x68 GB
.
.  Tdev Name          Size   Used Pool Attr         Host Group
.  ---- ----          ----   ---- ---- ----         ----------
.  3afc HOST2_3AFC_R1 34 GB  73%  6    CVS|HORC|THP HG_HOST2[7G11:3|7Q11:3|8G11:3|8Q11:3](4)
.  3afd HOST2_3AFD_R1 34 GB  99%  6    CVS|HORC|THP HG_HOST2[7G11:4|7Q11:4|8G11:4|8Q11:4](4)
.  3afe HOST2_3AFE_R1 34 GB  44%  6    CVS|HORC|THP HG_HOST2[7G11:5|7Q11:5|8G11:5|8Q11:5](4)
.  3aff HOST2_3AFF_R1 34 GB  40%  6    CVS|HORC|THP HG_HOST2[7G11:6|7Q11:6|8G11:6|8Q11:6](4)
.  3b00 HOST2_3B00_R1 34 GB  51%  6    CVS|HORC|THP HG_HOST2[7G11:7|7Q11:7|8G11:7|8Q11:7](4)
[...]
.
.
.
. Command(s) To Execute
......................................................................
.
.  <> Remove Replication By Copy.Grp [CG_HOST2_APP1] on Local Bay (ARRAY_A)
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.  pairsplit -g CG_HOST2_APP1 -S -I001
.
.  <> Remove Lun(s) to Dev.Group [DG_HOST2_APP1] on Local Bay (ARRAY_A)
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.  raidcom delete device_grp -device_grp_name DG_HOST2_APP1 -ldev_id 0x3afc -fx -I001
.  raidcom delete device_grp -device_grp_name DG_HOST2_APP1 -ldev_id 0x3afd -fx -I001
[...]
.
.  <> Remove Replication By Copy.Grp [CG_HOST1_ROOT] on Local Bay (ARRAY_A)
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.  pairsplit -g CG_HOST1_ROOT -S -I001
.
.  <> Remove Replication By Copy.Grp [CG_HOST1_APP2] on Local Bay (ARRAY_A)
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.  pairsplit -g CG_HOST1_APP2 -S -I001
.
.  <> Remove Lun(s) to Dev.Group [DG_HOST1_APP2] on Local Bay (ARRAY_A)
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.  raidcom delete device_grp -device_grp_name DG_HOST1_APP2 -ldev_id 0x3b01 -fx -I001
.  raidcom delete device_grp -device_grp_name DG_HOST1_APP2 -ldev_id 0x3b02 -fx -I001
[...]
.
.  <> Unmap Lun(s) on Local Bay (ARRAY_A)
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.  raidcom delete lun -port CL7-G HG_HOST1 -ldev_id 0x3afb -fx -I001
.  raidcom delete lun -port CL8-Q HG_HOST1 -ldev_id 0x3afb -fx -I001
.  raidcom delete lun -port CL8-G HG_HOST1 -ldev_id 0x3afb -fx -I001
.  raidcom delete lun -port CL7-Q HG_HOST1 -ldev_id 0x3afb -fx -I001
.  raidcom delete lun -port CL7-G HG_HOST1 -ldev_id 0x3afc -fx -I001
.  raidcom delete lun -port CL8-Q HG_HOST1 -ldev_id 0x3afc -fx -I001
.  raidcom delete lun -port CL8-G HG_HOST1 -ldev_id 0x3afc -fx -I001
.  raidcom delete lun -port CL7-Q HG_HOST1 -ldev_id 0x3afc -fx -I001
[...]
.
.  <> Delete Host(s) Group on Local Bay (ARRAY_A)
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.  raidcom delete host_grp -port CL7-G HG_HOST1 -fx -I001
.  raidcom delete host_grp -port CL7-Q HG_HOST1 -fx -I001
.  raidcom delete host_grp -port CL8-G HG_HOST1 -fx -I001
.  raidcom delete host_grp -port CL8-Q HG_HOST1 -fx -I001
.
.  <> Delete Lun(s) on Local Bay (ARRAY_A)
.     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.  raidcom delete ldev -ldev_id 0x3afb -I001
.  raidcom delete ldev -ldev_id 0x3afc -I001
.  raidcom delete ldev -ldev_id 0x3afd -I001
[...]
.
.  () Restore Config File
.
.   <!> Warning : Lun(s) With Active Replication [3afb,3afc,3afd,3afe,3aff,3b00,3b01,3b02,3b03,3b04,3b05,3b6e,3ea5,3b2e,3b2f,3b30]. Script Delete It (For Lun(s) to Remove Only)
.
. <> Do You Want Execute Command [y|n] ? .
```

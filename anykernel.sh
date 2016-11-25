# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers


## AnyKernel setup
# EDIFY properties
kernel.name=Test
do.devicecheck=1
device.name1=lux
do.modules=1
do.initd=1
do.cleanup=1

# shell variables
block=/dev/block/bootdevice/by-name/boot;
bindir=/system/bin;
libmodule=/system/lib/modules;
initd=/system/etc/init.d;
is_slot_device=0;

## end setup

## AnyKernel methods (DO NOT CHANGE)
# set up extracted files and directories
bin=/tmp/anykernel/tools;
split_img=/tmp/anykernel/split_img;
ramdisk=/tmp/anykernel/ramdisk;

chmod -R 755 $bin;
mkdir -p $ramdisk $split_img;

if [ "$is_slot_device" == 1 ]; then
  slot=$(getprop ro.boot.slot_suffix 2>/dev/null);
  test ! "$slot" && slot=$(grep -o 'androidboot.slot_suffix=.*$' /proc/cmdline | cut -d\  -f1 | cut -d= -f2);
  test "$slot" && block=$block$slot;
  if [ $? != 0 -o ! -e "$block" ]; then
    ui_print " "; ui_print "Unable to determine active boot slot. Aborting..."; exit 1;
  fi;
fi;

OUTFD=/proc/self/fd/$1;

# ui_print <text>
ui_print() { echo -e "ui_print $1\nui_print" > $OUTFD; }

# contains <string> <substring>
contains() { test "${1#*$2}" != "$1" && return 0 || return 1; }

# dump boot and extract ramdisk
dump_boot() {
  dd if=$block of=/tmp/anykernel/boot.img;
  $bin/unpackbootimg -i /tmp/anykernel/boot.img -o $split_img;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Error: dumping/splitting image failed."; exit 1;
  fi;
  mv -f $ramdisk /tmp/anykernel/rdtmp;
  mkdir -p $ramdisk;
  cd $ramdisk;
  gunzip -c $split_img/boot.img-ramdisk.gz | cpio -i;
  if [ $? != 0 -o -z "$(ls $ramdisk)" ]; then
    ui_print " "; ui_print "Error: unpacking ramdisk failed."; exit 1;
  fi;
  cp -af /tmp/anykernel/rdtmp/* $ramdisk;
}

# repack ramdisk then build and write image
write_boot() {
  cd $split_img;
  cmdline=`cat *-cmdline`;
  board=`cat *-board`;
  base=`cat *-base`;
  pagesize=`cat *-pagesize`;
  kerneloff=`cat *-kerneloff`;
  ramdiskoff=`cat *-ramdiskoff`;
  tagsoff=`cat *-tagsoff`;
  osver=`cat *-osversion`;
  oslvl=`cat *-oslevel`;
  if [ -f *-second ]; then
    second=`ls *-second`;
    second="--second $split_img/$second";
    secondoff=`cat *-secondoff`;
    secondoff="--second_offset $secondoff";
  fi;
  if [ -f /tmp/anykernel/zImage ]; then
    kernel=/tmp/anykernel/zImage;
  elif [ -f /tmp/anykernel/zImage-dtb ]; then
    kernel=/tmp/anykernel/zImage-dtb;
  else
    kernel=`ls *-zImage`;
    kernel=$split_img/$kernel;
  fi;
  if [ -f /tmp/anykernel/dtb ]; then
    dtb="--dt /tmp/anykernel/dtb";
  elif [ -f *-dtb ]; then
    dtb=`ls *-dtb`;
    dtb="--dt $split_img/$dtb";
  elif [ -f /tmp/anykernel/dt.img ]; then
    dtb="--dt /tmp/anykernel/dt.img";
  fi;
  if [ -f "$bin/mkbootfs" ]; then
    $bin/mkbootfs /tmp/anykernel/ramdisk | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
  else
    cd $ramdisk;
    find . | cpio -H newc -o | gzip > /tmp/anykernel/ramdisk-new.cpio.gz;
  fi;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Error: repacking ramdisk failed."; exit 1;
  fi;
  $bin/mkbootimg --kernel $kernel --ramdisk /tmp/anykernel/ramdisk-new.cpio.gz $second --cmdline "$cmdline" --board "$board" --base $base --pagesize $pagesize --kernel_offset $kerneloff --ramdisk_offset $ramdiskoff $secondoff --tags_offset $tagsoff --os_version "$osver" --os_patch_level "$oslvl" $dtb --output /tmp/anykernel/boot-new.img;
  if [ $? != 0 ]; then
    ui_print " "; ui_print "Error: repacking image failed."; exit 1;
  elif [ `wc -c < /tmp/anykernel/boot-new.img` -gt `wc -c < /tmp/anykernel/boot.img` ]; then
    ui_print " "; ui_print "Error: new image larger than boot partition."; exit 1;
  fi;
  dd if=/tmp/anykernel/boot-new.img of=$block;
}
## end methods

## AnyKernel install
dump_boot;
write_boot;
## end install

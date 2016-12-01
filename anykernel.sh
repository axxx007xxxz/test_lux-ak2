# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers


# EDIFY properties
kernel.name=Test
do.devicecheck=1
device.name1=lux
do.modules=1
do.initd=1
do.cleanup=1


# shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;


# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh;


# begin ramdisk changes
# set permissions for included ramdisk files
chmod -R 755 $ramdisk

# end ramdisk changes


## AnyKernel install
dump_boot;
write_boot;
## end install

# Save the Software RAID layout

if [ -e /proc/mdstat ] &&  grep -q blocks /proc/mdstat ; then
    LogPrint "Saving Software RAID configuration."
    (
        while read array device junk ; do
            if [ "$array" != "ARRAY" ] ; then
                continue
            fi
            
            # We use the detailed mdadm output quite alot
            mdadm --misc --detail $device > $TMP_DIR/mdraid
            
            # Gather information
            level=$( grep "Raid Level" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2")
            uuid=$( grep "UUID" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2-")
            layout=$( grep "Layout" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2")
            chunksize=$( grep "Chunk Size" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2" | sed -r 's/^([0-9]+).+/\1/')
            
            ndevices=$( grep "Raid Devices" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2")
            totaldevices=$( grep "Total Devices" $TMP_DIR/mdraid | tr -d " " | cut -d ":" -f "2")
            let sparedevices=$totaldevices-$ndevices
            
            # Find all devices
            # use the output of mdadm, but skip the array itself
            # sysfs has the information in RHEL 5+, but RHEL 4 lacks it.
            devices=""
            for disk in $( grep -o -E "/dev/[^m].*$" $TMP_DIR/mdraid | tr "\n" " ") ; do
                disk=$( get_friendly_name ${disk/!/\/} )
                if [ -z "$devices" ] ; then
                    devices=" devices=/dev/$disk"
                else
                    devices="$devices,/dev/$disk"
                fi
            done
            
            # prepare for output
            level=" level=$level"
            ndevices=" raid-devices=$ndevices"
            uuid=" uuid=$uuid"
            
            if [ "$sparedevices" -gt 0 ] ; then
                sparedevices=" spare-devices=$sparedevices"
            else
                sparedevices=""
            fi
            
            if [ -n "$layout" ] ; then
                layout=" layout=$layout"
            else
                layout=""
            fi
            
            if [ -n "$chunksize" ] ; then
                chunksize=" chunk=$chunksize"
            else
                chunksize=""
            fi
            
            echo "raid ${device}${level}${ndevices}${uuid}${sparedevices}${layout}${chunksize}${devices}"
        done < <(mdadm --detail --scan --config=partitions)
    ) >> $DISKLAYOUT_FILE
fi

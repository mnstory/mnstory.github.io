#!/bin/bash
# redirect pci, write by mnstory.net@20160607
main()
{
    if ! grep -P 'intel_iommu=on|iommu=pt' /proc/cmdline >/dev/null; then
        echo "please switch on iommu in kernel params first"
        echo "for aSV, execute follow commands: "
        echo "    sed -i 's/intel_iommu=off/intel_iommu=on/g' /boot/boot/grub/grub.cfg"
        echo "    reboot -f"
        return 1
    fi
    
    local filter="HBA"
    if [ -n "$1" ]; then
        echo "use '$1' replace filter '$filter'"
        filter="$1"
    else
        echo "use '$filter' as default filter, you can pass your own"
    fi
    
    modprobe pci_stub

    local args=""
    for id in $(lspci -nn -D | grep "$filter" | awk '{print $1}'); do
        local vender="$(lspci -s $id -n | awk '{print $3}' | awk -F: '{print $1,$2}')"
        echo $vender > /sys/bus/pci/drivers/pci-stub/new_id
        echo $id > /sys/bus/pci/devices/$id/driver/unbind
        echo $id > /sys/bus/pci/drivers/pci-stub/bind
        if lspci -s $id -nnvD | grep pci-stub >/dev/null; then
            echo -e "parse "$(lspci -s $id -nnD) "\033[01;32mSUCCESS\033[00m"
            args="$args -device pci-assign,host=$id"
        fi
    done
    
    if [ -z "$args" ]; then
        echo "no target device found filter by $filter"
        return 1
    fi

    echo "add follow args as your QEMU params(filter by $filter)"
    echo -e "\033[1m   $args\033[00m"
    return 0
}

main "$@"

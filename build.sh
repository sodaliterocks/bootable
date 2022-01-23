#!/usr/bin/env bash
# Usage: ./build.sh [variant] [ostree-repo] [working-dir]

. "$(dirname "$(realpath -s "$0")")/lib/sodaliterocks.common/bash/common.sh"

function update_submodules() {
    dir="$1"

    if [[ "$(ls -A $dir)" ]]; then
        echoc "$(write_emoji "🔄")Updating submodules..."
        git -C $dir submodule update --recursive
    else
        echoc "$(write_emoji "⬇️")Initializing submodules..."
        git -C $dir submodule update --init --recursive
    fi
}

base_dir="$(dirname "$(realpath -s "$0")")"
variant=$1
ostree_repo=$2
working_dir=$3

[[ -z $variant ]] && variant="base"
[[ -z $working_dir ]] && working_dir="$base_dir/build"

update_submodules $base_dir

test_root

if [[ -d $working_dir ]]; then
    echoc "$(write_emoji "🗑️")Removing old build..."
    rm -rf $working_dir
fi

orig_dir=$(pwd)

mkdir -p $working_dir
chown -R root:root $working_dir
cd $working_dir

iso_product=Sodalite
iso_version=stable # TODO: Get this from the OSTree build
iso_version_base=rawhide # TODO: Get this from the OSTree build
iso_version_release="$(date +"%Y%m%d")"
iso_variant=$variant # TODO: Get this from the OSTree build
iso_arch=x86_64 # TODO: Get this from the OSTree build
iso_ostree_oskey=${iso_product,,}-$iso_version_base-${iso_variant,,}
iso_ostree_repo_install=https://ostree.sodalite.rocks/
iso_ostree_repo_update=$iso_ostree_repo_install
iso_ostree_ref_install=sodalite/stable/x86_64/$variant # TODO: Get this from the OSTree build
iso_ostree_ref_update=$iso_ostree_ref_install
config_template=$base_dir/lib/fedora-lorax-templates/ostree-based-installer/lorax-configure-repo.tmpl
repo_template=$base_dir/lib/fedora-lorax-templates/ostree-based-installer/lorax-embed-repo.tmpl
flatpak_template_1=$base_dir/lib/fedora-lorax-templates/ostree-based-installer/lorax-embed-flatpaks_1.tmpl
flatpak_template_2=$base_dir/lib/fedora-lorax-templates/ostree-based-installer/lorax-embed-flatpaks_2.tmpl
runcmd=$base_dir/lib/fedora-lorax-templates/ostree-based-installer/runcmd.tmpl

echoc "$(write_emoji "📀")Building ISO (this will take a while)..."
exec lorax  --product=$iso_product \
            --version=$iso_version_base \
            --source=https://kojipkgs.fedoraproject.org/compose/$iso_version_base/latest-Fedora-Rawhide/compose/Everything/$iso_arch/os/ \
            --variant=$iso_variant \
            --release=$iso_version_release \
            --nomacboot \
            --volid="$iso_product-$iso_arch-$iso_version_base-$iso_version_release" \
            --add-template=$config_template \
            --add-template=$repo_template \
            --add-template=$flatpak_template_2 \
            --add-template=$flatpak_template_1 \
            --add-template=$runcmd \
            --add-template-var=ostree_install_repo=$iso_ostree_repo_install \
            --add-template-var=ostree_update_repo=$iso_ostree_repo_update \
            --add-template-var=ostree_osname=fedora \
            --add-template-var=ostree_oskey=$iso_ostree_oskey \
            --add-template-var=ostree_install_ref=$iso_ostree_ref_install \
            --add-template-var=ostree_update_ref=$iso_ostree_ref_update \
            --add-template-var=flatpak_remote_name_1=appcenter \
            --add-template-var=flatpak_remote_url_1=https://flatpak.elementary.io/repo.flatpakrepo \
            --add-template-var=flatpak_remote_refs_1="runtime/io.elementary.Platform/x86_64/6.1 app/org.gnome.Epiphany/x86_64/stable app/org.gnome.Evince/x86_64/stable app/org.gnome.FileRoller/x86_64/stable" \
            --add-template-var=flatpak_remote_name_2=flathub \
            --add-template-var=flatpak_remote_url_2=https://flathub.org/repo/flathub.flatpakrepo \
            --add-template-var=flatpak_remote_refs_2="runtime/org.freedesktop.Platform.GL.default/x86_64/21.08" \
            --add-template-var=cmd="rpm-ostree initramfs --enable" \
            --logfile=$working_dir/lorax.log \
            --tmp=$working_dir/tmp \
            --rootfs-size=8 \
            $working_dir/output

echoc "$(write_emoji "🛡️")Correcting permissions for build directory..."
real_user=$(get_sudo_user)
chown -R $real_user:$real_user $working_dir

cd $orig_dir

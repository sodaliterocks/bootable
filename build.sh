#!/usr/bin/env bash

# Massive props to ACertainTopfi for the initial work to get this going!
# (https://github.com/electricduck/sodalite/pull/10)

. "$(dirname "$(realpath -s "$0")")/lib/sodaliterocks.sodalite/src/include/tools/common.sh"

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
ostree_repo=$1
variant=$2
working_dir=$3

[[ -z $variant ]] && variant="custom"
[[ -z $working_dir ]] && working_dir="$base_dir/build"

update_submodules $base_dir

test_root

if [[ -z $ostree_repo ]]; then
    # Let's see if we can find a repo!
    declare -a possible_repo_name=(
        "sodalite"
        "electricduck.sodalite"
        "sodaliterocks.sodalite"
    )

    for i in "${possible_repo_name[@]}"
    do
        possible_repo_location="$base_dir/../$i/build/repo"
        if [[ -d $possible_repo_location ]]; then
            if [[ "$(ls -A $possible_repo_location)" ]]; then
                possible_repo_location=$(realpath -s $possible_repo_location)
                if [[ $(get_answer "Found OSTree repository at '$possible_repo_location'. Use?") == true ]]; then
                    ostree_repo=$possible_repo_location
                fi
            fi
        fi
    done
fi

if [[ -z $ostree_repo ]]; then
    echoc error "OSTree repository path required (\$1)"
    exit
else
    if [[ -d $ostree_repo ]]; then
        ostree summary -v --repo "$ostree_repo" > /dev/null 2>&1
        if [[ $? != 0 ]]; then
            echoc error "Not an OSTree repository ($ostree_repo)"
            exit
        fi
    else
        echoc error "OSTree repository does not exist ($ostree_repo)"
        exit
    fi
fi

if [[ -d $working_dir ]]; then
    echoc "$(write_emoji "🗑️")Removing old build..."
    rm -rf $working_dir
fi

orig_dir=$(pwd)

mkdir -p $working_dir
chown -R root:root $working_dir
cd $working_dir

iso_product="Sodalite"
iso_version="stable" # TODO: Get this from the OSTree build
iso_version_base="35" # TODO: Get this from the OSTree build
iso_version_release="$(date +"%Y%m%d")"
iso_variant=$variant # TODO: Get this from the OSTree build
iso_arch="x86_64" # TODO: Get this from the OSTree build
iso_ostree_oskey="${iso_product,,}-$iso_version_base-${iso_variant,,}"
iso_ostree_repo_install=$ostree_repo
iso_ostree_repo_update="https://ostree.zio.sh/repo"
iso_ostree_ref_install="sodalite/stable/x86_64/$variant" # TODO: Get this from the OSTree build
iso_ostree_ref_update=$iso_ostree_ref_install

echoc "$(write_emoji "📀")Building ISO (this will take a while)..."
exec lorax --product=$iso_product \
            --version=$iso_version_base \
            --source=https://kojipkgs.fedoraproject.org/compose/$iso_version_base/latest-Fedora-$iso_version_base/compose/Everything/$iso_arch/os/ \
            --variant=$iso_variant \
		    --release=$iso_release \
            --nomacboot \
            --volid="$iso_product-$iso_arch-$iso_version_base-$iso_release" \
            --add-template=$base_dir/lib/fedora-lorax-templates/ostree-based-installer/lorax-configure-repo.tmpl \
            --add-template=$base_dir/lib/fedora-lorax-templates/ostree-based-installer/lorax-embed-repo.tmpl \
            --add-template-var=ostree_install_repo=file://$iso_ostree_repo_install \
            --add-template-var=ostree_update_repo=$iso_ostree_repo_update \
            --add-template-var=ostree_osname=fedora \
            --add-template-var=ostree_oskey=$iso_ostree_oskey \
            --add-template-var=ostree_install_ref=$iso_ostree_ref_install \
            --add-template-var=ostree_update_ref=$iso_ostree_ref_update \
            --add-template=$base_dir/lib/fedora-lorax-templates/ostree-based-installer/lorax-embed-flatpaks.tmpl \
            --add-template-var=flatpak_remote_name="AppCenter" \
            --add-template-var=flatpak_remote_url=https://flatpak.elementary.io/repo.flatpakrepo \
            --add-template-var=flatpak_remote_refs="runtime/io.elementary.Platform/x86_64/6.1 app/org.gnome.Evince/x86_64/stable app/org.gnome.FileRoller/x86_64/stable" \
            --logfile=$working_dir/lorax.log \
            --tmp=$working_dir/tmp \
            --rootfs-size=8 \
            $working_dir/output

echoc "$(write_emoji "🛡️")Correcting permissions for build directory..."
real_user=$(get_sudo_user)
chown -R $real_user:$real_user $working_dir

cd $orig_dir

#!/bin/bash
set -e

cd "`dirname \"$0\"`"

image="$1"

if [ -z "$image" ]
then
  echo "# Please pass the image as the first argument!"
  exit 1
fi

echo "# Installing tools ... "
sudo apt-get -y -qq install squashfs-tools

echo "# Reading ISO contents ... "
image_name="`basename \"$image\"`"
mount_point="$image_name-mount"
filesystem="$image_name-filesystem"
mkdir -p "$mount_point"
if [ -z "`ls \"$mount_point\" 2>/dev/null`" ]
then
  sudo mount -o loop "$image" "$mount_point"
else
  echo "# This was done before, doing nothing."
fi

echo "# Unpacking the file system."
if [ -z "`ls \"$filesystem\" 2>/dev/null`" ]
then
  filesystem_squashfs="$mount_point/`( cd \"$mount_point\" && find -name filesystem.squashfs )`"
  echo "# extracting filesystem from $filesystem_squashfs"
  mkdir -p "$filesystem"
  sudo unsquashfs -f -d "$filesystem" "$filesystem_squashfs"
else
  echo "# This was done before, doing nothing."
fi


echo "# Creting files for docker image"
dockerfile_iso_path="docker/iso"
dockerfile_filesystem="docker/filesystem"
rm -f "$dockerfile_iso_path" "$dockerfile_filesystem"
ln -s -T "$mount_point" "$dockerfile_iso_path"
ln -s -T "$filesystem" "$dockerfile_filesystem"

echo "# Creating docker image name accoring to"
echo "#   https://github.com/docker/docker/blob/master/image/spec/v1.md"
dockerhub_organization="codersosimages"
docker_image_name="`echo \"${image_name%.*}\" | tr -c '[:alnum:]._-' _`"
full_docker_image_name="$dockerhub_organization/$docker_image_name"
echo "# labels: $docker_image_name and $full_docker_image_name"

docker build --label "$full_docker_image_name" --label "$docker_image_name" docker

echo "# Pushing the image to dockerhub"
if ! [ -e "~/.docker/config.json" ]
then
  docker login
fi
docker push "$full_docker_image_name"

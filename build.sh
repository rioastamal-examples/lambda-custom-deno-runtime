#!/bin/bash
#
# @author Rio Astamal <rio@rioastamal.net>
# @link https://teknocerdas.com/programming/tutorial-serverless-membuat-lambda-custom-runtime-untuk-deno
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

BASE_DIR=$( dirname "$0" )
ABS_DIR=$( realpath $BASE_DIR )

build_layer()
{
  local DENO_VERSION="1.0.2"

  echo "> Starting to build Lambda Layer for Deno..."
  mkdir -p $ABS_DIR/src/layer/{tmp,bin}

  echo "> Removing old layer..."
  rm $ABS_DIR/build/layer.zip 2>/dev/null && echo "< done."

  [ ! -f $ABS_DIR/src/layer/bin/deno ] && {
    echo "> Downloading deno ${DENO_VERSION} binary release from GitHub..."

    # We use binary from hayd because official deno binary unable to run on Amazon Linux 1 because
    # it is based on RHEL 7/CentOS 7. There are glibc issue.
    # @see https://github.com/denoland/deno/issues/1658
    curl -L "https://github.com/hayd/deno-lambda/releases/download/${DENO_VERSION}/amz-deno.gz" -o \
      $ABS_DIR/src/layer/tmp/amz-deno.gz && echo "< done."

    echo "> Extracting deno binary..."
    gunzip $ABS_DIR/src/layer/tmp/amz-deno.gz -c > $ABS_DIR/src/layer/bin/deno && echo "< done."

    echo "> Moving binary release to ./bin/ directory..."
    mv $ABS_DIR/src/layer/tmp/deno $ABS_DIR/src/layer/bin/deno && echo "< done."
  }

  echo "> Removing tmp/ directory..."
  rm -rf $ABS_DIR/src/layer/tmp 2>/dev/null && echo "< done."

  echo "> Creating zip for Layer..."
  chmod +x $ABS_DIR/src/layer/bin/deno

  cd $ABS_DIR/src/layer && \
    zip $ABS_DIR/build/layer.zip -r ./ && echo "< done."
}

build_function()
{
  echo "> Creating zip archive for Deno source..."
  chmod +x $ABS_DIR/src/function/bootstrap

  cd $ABS_DIR/src/function && \
    zip $ABS_DIR/build/function.zip -x ./event.json -r ./ && echo "< done."

  # Notes for improvement.
  # We can run the script first to generate the cached files and then
  # copy the cached files into the zip.
  # E.g .deno
  #
  # But we need to map all files in .deno/gen/file/* so it is matched with
  # directory inside Lambda environment
}

mkdir -p $ABS_DIR/build
rm -r $ABS_DIR/build/*.zip

build_layer
build_function
#!/usr/bin/env bash

set -e

TARGET_DIR="models"
KICAD_3DMODEL_DIR="/Applications/KiCad/KiCad.app/Contents/SharedSupport/3dmodels"

# Find all .kicad_mod files
find ./footprints -name "*.kicad_mod" -type f | while read -r modfile; do
    modfile_with_ext="${modfile##*/}"
    modname="${modfile_with_ext%.*}"

    # Extract model paths
    grep -oE 'model "[^"]+"' "$modfile" | while read -r line; do
        # Extract the quoted path
        model_path=$(echo "$line" | sed -E 's/model "([^"]+)"/\1/')

        # Ignore variables starting with ${HW_COMP}
        if [[ "$model_path" == \${HW_COMP}* ]]; then
            continue
        fi

        # Resolve absolute path of the model file
        if [[ "$model_path" == \${KICAD?_3DMODEL_DIR}* ]]; then
            src_path="$KICAD_3DMODEL_DIR/${model_path#*/}"
        elif [[ "$model_path" = /* ]]; then
            src_path="$model_path"
        else
            src_path="$(dirname "$modfile")/$model_path"
        fi

        # Skip if source file does not exist
        if [[ ! -f "$src_path" ]]; then
            echo "Warning: model not found: $src_path (referenced in $modfile)"
            continue
        fi

        extension="${src_path##*.}"
        if [[ "$extension" == "wrl" ]]; then
            # Prefer STEP over WRL if both exist.
            if [[ -f "${src_path%.wrl}.step" ]]; then
                extension="step"
                src_path="${src_path%.wrl}.step"
            fi
        fi

        filename="$modname.$extension"
        dest_path="./$TARGET_DIR/$filename"

        echo "Copying model from '$src_path' to '$dest_path' and updating '$modfile'"

        # Copy model if not already copied
        if [[ ! -f "$dest_path" ]]; then
            cp "$src_path" "$dest_path"
        fi

        # Replace model path in the .kicad_mod file
        sed -i.bak \
            "s|model \"$model_path\"|model \"\${HW_COMP}/$TARGET_DIR/$filename\"|g" \
            "$modfile"
    done
done

echo "Done. Models collected in '$TARGET_DIR/'. Backup files (*.bak) were created."

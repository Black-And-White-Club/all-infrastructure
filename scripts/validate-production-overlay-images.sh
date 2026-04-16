#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
	echo "usage: $0 <overlay-kustomization.yaml> <rendered-manifest.yaml>" >&2
	exit 2
fi

overlay_file="$1"
rendered_manifest="$2"

if [[ ! -f "$overlay_file" ]]; then
	echo "ERROR: overlay file not found: $overlay_file" >&2
	exit 2
fi

if [[ ! -f "$rendered_manifest" ]]; then
	echo "ERROR: rendered manifest file not found: $rendered_manifest" >&2
	exit 2
fi

analysis="$(
	awk '
		BEGIN {
			in_images=0
			images_blocks=0
			entry_count=0
			current=""
		}
		/^images:[[:space:]]*$/ {
			in_images=1
			images_blocks++
			next
		}
		in_images && /^[^[:space:]-][^:]*:/ {
			in_images=0
		}
		in_images && /^  - name:[[:space:]]*/ {
			entry_count++
			current=entry_count
			sub(/^  - name:[[:space:]]*/, "", $0)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
			names[current]=$0
			next
		}
		in_images && /^    newName:[[:space:]]*/ {
			sub(/^    newName:[[:space:]]*/, "", $0)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
			new_names[current]=$0
			next
		}
		in_images && /^    newTag:[[:space:]]*/ {
			sub(/^    newTag:[[:space:]]*/, "", $0)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
			new_tags[current]=$0
			next
		}
		END {
			print "images_blocks=" images_blocks
			print "entry_count=" entry_count
			for (i = 1; i <= entry_count; i++) {
				print "name_" i "=" names[i]
				print "new_name_" i "=" new_names[i]
				print "new_tag_" i "=" new_tags[i]
			}
		}
	' "$overlay_file"
)"

images_blocks="$(printf '%s\n' "$analysis" | awk -F= '$1=="images_blocks"{print $2}')"
entry_count="$(printf '%s\n' "$analysis" | awk -F= '$1=="entry_count"{print $2}')"

if [[ "$images_blocks" -ne 1 ]]; then
	echo "ERROR: overlay must define exactly one images: block" >&2
	exit 1
fi

if [[ "$entry_count" -lt 1 || "$entry_count" -gt 2 ]]; then
	echo "ERROR: overlay must define one bootstrap image entry and at most one updater-owned image entry" >&2
	exit 1
fi

placeholder_count=0
updater_count=0
placeholder_name=""
placeholder_new_name=""
placeholder_new_tag=""
effective_image_name=""
effective_image_tag=""

for ((i = 1; i <= entry_count; i++)); do
	name="$(printf '%s\n' "$analysis" | awk -F= -v key="name_${i}" '$1==key{print $2}')"
	new_name="$(printf '%s\n' "$analysis" | awk -F= -v key="new_name_${i}" '$1==key{print $2}')"
	new_tag="$(printf '%s\n' "$analysis" | awk -F= -v key="new_tag_${i}" '$1==key{print $2}')"

	if [[ -z "$name" ]]; then
		echo "ERROR: overlay image entry must define name" >&2
		exit 1
	fi

	if [[ "$name" == */* ]]; then
		updater_count=$((updater_count + 1))
		effective_image_name="$name"
		effective_image_tag="$new_tag"
		continue
	fi

	placeholder_count=$((placeholder_count + 1))
	placeholder_name="$name"
	placeholder_new_name="$new_name"
	placeholder_new_tag="$new_tag"
done

if [[ "$placeholder_count" -ne 1 ]]; then
	if [[ "$entry_count" -eq 1 && "$updater_count" -eq 1 ]]; then
		echo "ERROR: overlay image name must be a placeholder, not a fully qualified image: $effective_image_name" >&2
		exit 1
	fi
	echo "ERROR: overlay must define exactly one placeholder image entry" >&2
	exit 1
fi

if [[ -z "$placeholder_new_name" ]]; then
	echo "ERROR: overlay placeholder image entry must define newName" >&2
	exit 1
fi

if [[ -z "$placeholder_new_tag" ]]; then
	echo "ERROR: overlay placeholder image entry must define newTag" >&2
	exit 1
fi

if [[ "$updater_count" -gt 1 ]]; then
	echo "ERROR: overlay must define at most one updater-owned fully qualified image entry" >&2
	exit 1
fi

if [[ "$updater_count" -eq 0 ]]; then
	effective_image_name="$placeholder_new_name"
	effective_image_tag="$placeholder_new_tag"
elif [[ "$placeholder_new_name" != "$effective_image_name" ]]; then
	echo "ERROR: overlay placeholder newName must match updater-owned image entry: $placeholder_new_name vs $effective_image_name" >&2
	exit 1
fi

if [[ -z "$effective_image_tag" ]]; then
	echo "ERROR: effective image entry must define newTag" >&2
	exit 1
fi

if grep -Eq "image:[[:space:]]*${placeholder_name}([:@[:space:]]|$)" "$rendered_manifest"; then
	echo "ERROR: rendered manifest still contains placeholder image: $placeholder_name" >&2
	exit 1
fi

if ! grep -Eq "image:[[:space:]]*${effective_image_name}([:@][^[:space:]]+)?$" "$rendered_manifest"; then
	echo "ERROR: rendered manifest does not contain expected mapped image: $effective_image_name" >&2
	exit 1
fi

echo "production overlay image mapping checks passed for $overlay_file"

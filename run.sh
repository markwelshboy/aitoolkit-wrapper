 cd /app/ai-toolkit

mkdir datasets
cd datasets
hff get training/5H1V_QIE2511_custom_prompt_halflr_double_rank.yaml
cp 5H1V_QIE2511_custom_prompt_halflr_double_rank.yaml config.yaml
hff get training/5h1v.tar
tar -xvf 5h1v.tar
hff get training/5h1v_control_images.tar
tar -xvf 5h1v_control_images.tar
cd /app/ai-toolkit
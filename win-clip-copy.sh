#!/bin/bash
input=$(cat)
echo "$(date): $input" >> /tmp/clip-debug.log
echo -n "$input" | powershell.exe -NoProfile -Command '[Console]::InputEncoding = [System.Text.Encoding]::UTF8; Add-Type -AssemblyName System.Windows.Forms; $text = [Console]::In.ReadToEnd().TrimEnd([char]13,[char]10); [System.Windows.Forms.Clipboard]::SetText($text)'

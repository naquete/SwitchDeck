# ============================================================================
#  SwitchDeck - Interface gráfica (WinForms)
# ============================================================================

function Show-SwitchDeckGui {
    param([int]$TestClose = 0)   # >0: fecha a janela sozinha após N ms (para testes)

    $ui     = [System.Drawing.Color]::FromArgb(245,246,248)
    $accent = [System.Drawing.Color]::FromArgb(59,130,246)
    $font   = New-Object System.Drawing.Font('Segoe UI',9.75)
    $fontB  = New-Object System.Drawing.Font('Segoe UI',9.75,[System.Drawing.FontStyle]::Bold)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'SwitchDeck'
    $form.Size = New-Object System.Drawing.Size(700,600)
    $form.MinimumSize = New-Object System.Drawing.Size(560,460)
    $form.StartPosition = 'CenterScreen'
    $form.Font = $font
    $form.BackColor = $ui

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'; $tabs.Padding = New-Object System.Drawing.Point(14,6)

    function _btn($text,$w) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text=$text; $b.Height=32; $b.Width=$w; $b.FlatStyle='System'
        $b.Margin = New-Object System.Windows.Forms.Padding(0,0,8,0)
        return $b
    }
    function _lv($cols) {
        $lv = New-Object System.Windows.Forms.ListView
        $lv.View='Details'; $lv.FullRowSelect=$true; $lv.HideSelection=$false
        $lv.Dock='Fill'; $lv.MultiSelect=$false; $lv.BorderStyle='FixedSingle'
        foreach ($c in $cols) { [void]$lv.Columns.Add($c[0], $c[1]) }
        return $lv
    }
    function _fillAudio($lv, $devices) {
        $lv.BeginUpdate(); $lv.Items.Clear()
        foreach ($d in $devices) {
            $it = New-Object System.Windows.Forms.ListViewItem($d.Name)
            [void]$it.SubItems.Add($(if($d.IsDefault){'●'}else{''}))
            if ($d.IsDefault) { $it.Font=$fontB; $it.ForeColor=$accent }
            $it.Tag=$d; [void]$lv.Items.Add($it)
        }
        $lv.EndUpdate()
    }
    function _sel($lv) { if ($lv.SelectedItems.Count -gt 0) { return $lv.SelectedItems[0].Tag }; return $null }
    function _warn($msg) { [void][System.Windows.Forms.MessageBox]::Show($msg,'SwitchDeck','OK','Information') }

    # ---------- ABA: SAÍDA DE ÁUDIO ----------
    $tabOut = New-Object System.Windows.Forms.TabPage; $tabOut.Text='  Saída de Áudio  '; $tabOut.BackColor=$ui; $tabOut.Padding=New-Object System.Windows.Forms.Padding(10)
    $lvOut = _lv @(,@('Dispositivo de saída',430),@('Padrão',70))
    $barOut = New-Object System.Windows.Forms.FlowLayoutPanel; $barOut.Dock='Bottom'; $barOut.Height=44; $barOut.Padding=New-Object System.Windows.Forms.Padding(0,8,0,0)
    $bSetOut=_btn 'Definir como padrão' 150; $bSetOut.Font=$fontB; $bScOut=_btn 'Criar atalho' 110; $bRfOut=_btn 'Atualizar' 90
    $barOut.Controls.AddRange(@($bSetOut,$bScOut,$bRfOut))
    $tabOut.Controls.Add($lvOut); $tabOut.Controls.Add($barOut)

    # ---------- ABA: MICROFONE ----------
    $tabMic = New-Object System.Windows.Forms.TabPage; $tabMic.Text='  Microfone  '; $tabMic.BackColor=$ui; $tabMic.Padding=New-Object System.Windows.Forms.Padding(10)
    $lvMic = _lv @(,@('Microfone',430),@('Padrão',70))
    $barMic = New-Object System.Windows.Forms.FlowLayoutPanel; $barMic.Dock='Bottom'; $barMic.Height=44; $barMic.Padding=New-Object System.Windows.Forms.Padding(0,8,0,0)
    $bSetMic=_btn 'Definir como padrão' 150; $bSetMic.Font=$fontB; $bScMic=_btn 'Criar atalho' 110; $bRfMic=_btn 'Atualizar' 90
    $barMic.Controls.AddRange(@($bSetMic,$bScMic,$bRfMic))
    $tabMic.Controls.Add($lvMic); $tabMic.Controls.Add($barMic)

    # ---------- ABA: MONITORES ----------
    $tabMon = New-Object System.Windows.Forms.TabPage; $tabMon.Text='  Monitores  '; $tabMon.BackColor=$ui; $tabMon.Padding=New-Object System.Windows.Forms.Padding(10)
    $lvMon = _lv @(,@('Perfil',170),@('Layout',220),@('Áudio vinculado',150))
    $barMon = New-Object System.Windows.Forms.FlowLayoutPanel; $barMon.Dock='Bottom'; $barMon.Height=44; $barMon.Padding=New-Object System.Windows.Forms.Padding(0,8,0,0)
    $bApply=_btn 'Aplicar' 90; $bApply.Font=$fontB; $bCap=_btn 'Capturar tela atual...' 160; $bScMon=_btn 'Criar atalho' 110; $bDel=_btn 'Excluir' 80; $bRfMon=_btn 'Atualizar' 90
    $barMon.Controls.AddRange(@($bApply,$bCap,$bScMon,$bDel,$bRfMon))
    $lblHint = New-Object System.Windows.Forms.Label; $lblHint.Dock='Top'; $lblHint.Height=36; $lblHint.ForeColor=[System.Drawing.Color]::FromArgb(90,95,105)
    $lblHint.Text='Arrume seus monitores nas Configurações do Windows, depois clique "Capturar tela atual" para salvar como perfil.'
    $tabMon.Controls.Add($lvMon); $tabMon.Controls.Add($lblHint); $tabMon.Controls.Add($barMon)

    $tabs.TabPages.AddRange(@($tabOut,$tabMic,$tabMon))

    # ---------- RODAPÉ ----------
    $foot = New-Object System.Windows.Forms.Panel; $foot.Dock='Bottom'; $foot.Height=38; $foot.BackColor=[System.Drawing.Color]::FromArgb(235,237,240)
    $lblFoot = New-Object System.Windows.Forms.Label; $lblFoot.Dock='Fill'; $lblFoot.TextAlign='MiddleLeft'; $lblFoot.Padding=New-Object System.Windows.Forms.Padding(10,0,0,0)
    $lblFoot.Text='Atalhos p/ Stream Deck:  ' + $ShortDir; $lblFoot.ForeColor=[System.Drawing.Color]::FromArgb(70,75,85)
    $bOpen = New-Object System.Windows.Forms.Button; $bOpen.Text='Abrir pasta de atalhos'; $bOpen.Dock='Right'; $bOpen.Width=180; $bOpen.FlatStyle='System'
    $foot.Controls.Add($lblFoot); $foot.Controls.Add($bOpen)
    $form.Controls.Add($tabs); $form.Controls.Add($foot)

    # ---------- REFRESH ----------
    function RefreshOut { _fillAudio $lvOut (Get-SDAudioOutputs) }
    function RefreshMic { _fillAudio $lvMic (Get-SDMicrophones) }
    function RefreshMon {
        $lvMon.BeginUpdate(); $lvMon.Items.Clear()
        foreach ($p in (Get-SDProfiles)) {
            $it = New-Object System.Windows.Forms.ListViewItem($p.Name)
            [void]$it.SubItems.Add($p.Desc); [void]$it.SubItems.Add($(if($p.AudioName){$p.AudioName}else{'—'}))
            $it.Tag=$p; [void]$lvMon.Items.Add($it)
        }
        $lvMon.EndUpdate()
    }

    # ---------- CAPTURA DE PERFIL ----------
    function Invoke-Capture {
        $dlg = New-Object System.Windows.Forms.Form
        $dlg.Text='Capturar perfil de monitor'; $dlg.Size=New-Object System.Drawing.Size(430,250); $dlg.StartPosition='CenterParent'; $dlg.FormBorderStyle='FixedDialog'; $dlg.MaximizeBox=$false; $dlg.MinimizeBox=$false; $dlg.Font=$font; $dlg.BackColor=$ui
        $l1=New-Object System.Windows.Forms.Label; $l1.Text=("Salvando o layout atual (" + [SwitchDeck.DisplayNative]::ActiveCount() + " tela(s)). Nome do perfil:"); $l1.Location='15,15'; $l1.Size='400,20'
        $tb=New-Object System.Windows.Forms.TextBox; $tb.Location='15,40'; $tb.Size='390,24'; $tb.Text='Meu perfil'
        $l2=New-Object System.Windows.Forms.Label; $l2.Text='Vincular uma saída de áudio (opcional):'; $l2.Location='15,78'; $l2.Size='400,20'
        $cb=New-Object System.Windows.Forms.ComboBox; $cb.Location='15,102'; $cb.Size='390,24'; $cb.DropDownStyle='DropDownList'
        [void]$cb.Items.Add('— Nenhum (não mexer no áudio) —')
        $outs=@(Get-SDAudioOutputs); foreach($o in $outs){ [void]$cb.Items.Add($o.Name) }; $cb.SelectedIndex=0
        $ok=New-Object System.Windows.Forms.Button; $ok.Text='Salvar'; $ok.Location='230,155'; $ok.Size='85,32'; $ok.DialogResult='OK'; $ok.Font=$fontB
        $ca=New-Object System.Windows.Forms.Button; $ca.Text='Cancelar'; $ca.Location='320,155'; $ca.Size='85,32'; $ca.DialogResult='Cancel'
        $dlg.Controls.AddRange(@($l1,$tb,$l2,$cb,$ok,$ca)); $dlg.AcceptButton=$ok; $dlg.CancelButton=$ca
        if ($dlg.ShowDialog($form) -eq 'OK' -and $tb.Text.Trim()) {
            $aid=$null; $anm=$null
            if ($cb.SelectedIndex -gt 0) { $s=$outs[$cb.SelectedIndex-1]; $aid=$s.Id; $anm=$s.Name }
            Save-SDProfile -Name $tb.Text.Trim() -AudioId $aid -AudioName $anm | Out-Null
            RefreshMon
        }
    }

    # ---------- HANDLERS ----------
    $bSetOut.Add_Click({ $d=_sel $lvOut; if($d){ Set-SDAudioDefault $d.Id; RefreshOut } else { _warn 'Selecione um dispositivo.' } })
    $lvOut.Add_DoubleClick({ $d=_sel $lvOut; if($d){ Set-SDAudioDefault $d.Id; RefreshOut } })
    $bScOut.Add_Click({ $d=_sel $lvOut; if($d){ $n=New-SDAudioShortcut -Device $d -OnDesktop; _warn "Atalho '$n' criado (área de trabalho + pasta Stream Deck)." } else { _warn 'Selecione um dispositivo.' } })
    $bRfOut.Add_Click({ RefreshOut })

    $bSetMic.Add_Click({ $d=_sel $lvMic; if($d){ Set-SDAudioDefault $d.Id; RefreshMic } else { _warn 'Selecione um microfone.' } })
    $lvMic.Add_DoubleClick({ $d=_sel $lvMic; if($d){ Set-SDAudioDefault $d.Id; RefreshMic } })
    $bScMic.Add_Click({ $d=_sel $lvMic; if($d){ $n=New-SDAudioShortcut -Device $d -Mic -OnDesktop; _warn "Atalho '$n' criado." } else { _warn 'Selecione um microfone.' } })
    $bRfMic.Add_Click({ RefreshMic })

    $bApply.Add_Click({ $p=_sel $lvMon; if($p){ $r=Invoke-SDProfile -File $p.File; if($r -ne 0){ _warn "O Windows recusou o perfil (código $r)." } } else { _warn 'Selecione um perfil.' } })
    $lvMon.Add_DoubleClick({ $p=_sel $lvMon; if($p){ Invoke-SDProfile -File $p.File | Out-Null } })
    $bCap.Add_Click({ Invoke-Capture })
    $bScMon.Add_Click({ $p=_sel $lvMon; if($p){ $n=New-SDProfileShortcut -ProfileName $p.Name -File $p.File -OnDesktop; _warn "Atalho '$n' criado." } else { _warn 'Selecione um perfil.' } })
    $bDel.Add_Click({ $p=_sel $lvMon; if($p){ if([System.Windows.Forms.MessageBox]::Show("Excluir o perfil '$($p.Name)'?",'SwitchDeck','YesNo','Question') -eq 'Yes'){ Remove-SDProfile -File $p.File; RefreshMon } } else { _warn 'Selecione um perfil.' } })
    $bRfMon.Add_Click({ RefreshMon })
    $bOpen.Add_Click({ Start-Process explorer.exe $ShortDir })

    RefreshOut; RefreshMic; RefreshMon

    if ($TestClose -gt 0) {
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = $TestClose
        $timer.Add_Tick({ $timer.Stop(); $form.Close() })
        $timer.Start()
    }
    [void]$form.ShowDialog()
    $form.Dispose()
}

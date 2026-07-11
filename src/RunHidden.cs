// SwitchDeck - lançador sem janela.
// App de subsistema "Windows" (sem console): inicia o PowerShell 100% invisível,
// eliminando o flash do terminal ao acionar atalhos.
using System;
using System.Diagnostics;
using System.IO;
class Launcher {
    static void Main() {
        string cmd = Environment.CommandLine;
        string tail;
        if (cmd.StartsWith("\"")) { int e = cmd.IndexOf('"', 1); tail = (e >= 0) ? cmd.Substring(e + 1) : ""; }
        else { int sp = cmd.IndexOf(' '); tail = (sp >= 0) ? cmd.Substring(sp + 1) : ""; }
        tail = tail.TrimStart();
        try {
            var psi = new ProcessStartInfo();
            psi.FileName = Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe");
            psi.Arguments = tail;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WindowStyle = ProcessWindowStyle.Hidden;
            Process.Start(psi);
        } catch { }
    }
}

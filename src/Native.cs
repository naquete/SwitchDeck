// SwitchDeck - código nativo (áudio via IPolicyConfig/MMDevice, monitores via CCD).
// Compilado uma vez para bin\SwitchDeck.Native.dll e carregado rapidamente depois.
using System;
using System.IO;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace SwitchDeck {

  public class AudioDevice { public string Id; public string Name; public bool IsDefault; }

  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator { }
  [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceEnumerator { int EnumAudioEndpoints(int dataFlow, int mask, out IMMDeviceCollection col); int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice dev); }
  [Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceCollection { int GetCount(out int c); int Item(int i, out IMMDevice d); }
  [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDevice { int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o); int OpenPropertyStore(int access, out IPropertyStore s); int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id); int GetState(out int st); }
  [Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPropertyStore { int GetCount(out int c); int GetAt(int i, out PROPERTYKEY k); int GetValue(ref PROPERTYKEY k, out PROPVARIANT v); }
  [StructLayout(LayoutKind.Sequential)] struct PROPERTYKEY { public Guid fmtid; public int pid; }
  [StructLayout(LayoutKind.Explicit)] struct PROPVARIANT { [FieldOffset(0)] public short vt; [FieldOffset(8)] public IntPtr p; }

  [ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")] class CPolicyConfigClient {}
  [Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPolicyConfig { int r0();int r1();int r2();int r3();int r4();int r5();int r6();int r7();int r8();int r9();
    int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role); }

  public static class AudioNative {
    static string NameOf(IMMDevice d) {
      IPropertyStore s; d.OpenPropertyStore(0, out s);
      var k = new PROPERTYKEY(); k.fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"); k.pid = 14;
      PROPVARIANT v; s.GetValue(ref k, out v); return Marshal.PtrToStringUni(v.p);
    }
    // dataFlow: 0 = render (saída), 1 = capture (microfone)
    public static AudioDevice[] List(int dataFlow) {
      var e = (IMMDeviceEnumerator)(new MMDeviceEnumerator());
      string defId = ""; IMMDevice dd;
      if (e.GetDefaultAudioEndpoint(dataFlow, 0, out dd) == 0) dd.GetId(out defId);
      IMMDeviceCollection col; e.EnumAudioEndpoints(dataFlow, 1, out col); // 1 = DEVICE_STATE_ACTIVE
      int n; col.GetCount(out n);
      var list = new List<AudioDevice>();
      for (int i = 0; i < n; i++) {
        IMMDevice d; col.Item(i, out d); string id; d.GetId(out id);
        list.Add(new AudioDevice { Id = id, Name = NameOf(d), IsDefault = (id == defId) });
      }
      return list.ToArray();
    }
    public static void SetDefault(string id) {
      var pc = (IPolicyConfig)(new CPolicyConfigClient());
      pc.SetDefaultEndpoint(id, 0); pc.SetDefaultEndpoint(id, 1); pc.SetDefaultEndpoint(id, 2);
    }
  }

  public static class DisplayNative {
    [StructLayout(LayoutKind.Sequential)] struct LUID { public uint Low; public int High; }
    [StructLayout(LayoutKind.Sequential)] struct RATIONAL { public uint Num; public uint Den; }
    [StructLayout(LayoutKind.Sequential)] struct PATH_SOURCE_INFO { public LUID adapterId; public uint id; public uint modeInfoIdx; public uint statusFlags; }
    [StructLayout(LayoutKind.Sequential)] struct PATH_TARGET_INFO {
      public LUID adapterId; public uint id; public uint modeInfoIdx; public uint outputTechnology;
      public uint rotation; public uint scaling; public RATIONAL refreshRate; public uint scanLineOrdering;
      public int targetAvailable; public uint statusFlags; }
    [StructLayout(LayoutKind.Sequential)] struct PATH_INFO { public PATH_SOURCE_INFO src; public PATH_TARGET_INFO tgt; public uint flags; }
    [StructLayout(LayoutKind.Sequential)] struct REGION { public uint cx; public uint cy; }
    [StructLayout(LayoutKind.Sequential)] struct VIDEO_SIGNAL { public ulong pixelRate; public RATIONAL hSync; public RATIONAL vSync; public REGION activeSize; public REGION totalSize; public uint videoStandard; public uint scanLineOrdering; }
    [StructLayout(LayoutKind.Sequential)] struct TARGET_MODE { public VIDEO_SIGNAL vsi; }
    [StructLayout(LayoutKind.Sequential)] struct POINTL { public int x; public int y; }
    [StructLayout(LayoutKind.Sequential)] struct SOURCE_MODE { public uint width; public uint height; public uint pixelFormat; public POINTL position; }
    [StructLayout(LayoutKind.Sequential)] struct RECTL { public int l, t, r, b; }
    [StructLayout(LayoutKind.Sequential)] struct DESKTOP_IMAGE { public POINTL sz; public RECTL region; public RECTL clip; }
    [StructLayout(LayoutKind.Explicit)] struct MODE_UNION {
      [FieldOffset(0)] public TARGET_MODE targetMode;
      [FieldOffset(0)] public SOURCE_MODE sourceMode;
      [FieldOffset(0)] public DESKTOP_IMAGE desktopImage; }
    [StructLayout(LayoutKind.Sequential)] struct MODE_INFO { public uint infoType; public uint id; public LUID adapterId; public MODE_UNION mode; }

    [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(uint flags, out uint nPath, out uint nMode);
    [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags, ref uint nPath, [Out] PATH_INFO[] paths, ref uint nMode, [Out] MODE_INFO[] modes, IntPtr topo);
    [DllImport("user32.dll")] static extern int SetDisplayConfig(uint nPath, [In] PATH_INFO[] paths, uint nMode, [In] MODE_INFO[] modes, uint flags);

    const uint QDC_ONLY_ACTIVE = 0x02;
    const uint SDC_APPLY = 0x80, SDC_USE_SUPPLIED = 0x20, SDC_SAVE_DB = 0x200, SDC_ALLOW_CHANGES = 0x400;

    static byte[] ToBytes<T>(T[] a) where T:struct {
      int sz = Marshal.SizeOf(typeof(T)); byte[] b = new byte[sz*a.Length]; IntPtr p = Marshal.AllocHGlobal(sz);
      for(int i=0;i<a.Length;i++){ Marshal.StructureToPtr(a[i], p, false); Marshal.Copy(p, b, i*sz, sz); }
      Marshal.FreeHGlobal(p); return b;
    }
    static T[] FromBytes<T>(byte[] b, int off, int count) where T:struct {
      int sz = Marshal.SizeOf(typeof(T)); T[] a = new T[count]; IntPtr p = Marshal.AllocHGlobal(sz);
      for(int i=0;i<count;i++){ Marshal.Copy(b, off+i*sz, p, sz); a[i]=(T)Marshal.PtrToStructure(p, typeof(T)); }
      Marshal.FreeHGlobal(p); return a;
    }
    static void QueryActive(out PATH_INFO[] paths, out MODE_INFO[] modes) {
      uint nP, nM; GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE, out nP, out nM);
      paths = new PATH_INFO[nP]; modes = new MODE_INFO[nM];
      QueryDisplayConfig(QDC_ONLY_ACTIVE, ref nP, paths, ref nM, modes, IntPtr.Zero);
      Array.Resize(ref paths, (int)nP); Array.Resize(ref modes, (int)nM);
    }
    public static void Save(string file) {
      PATH_INFO[] paths; MODE_INFO[] modes; QueryActive(out paths, out modes);
      using (var w = new BinaryWriter(File.Create(file))) {
        w.Write(paths.Length); w.Write(modes.Length); w.Write(ToBytes(paths)); w.Write(ToBytes(modes));
      }
    }
    public static int Load(string file) {
      byte[] all = File.ReadAllBytes(file);
      int nP = BitConverter.ToInt32(all,0); int nM = BitConverter.ToInt32(all,4);
      int pSz = Marshal.SizeOf(typeof(PATH_INFO));
      var paths = FromBytes<PATH_INFO>(all, 8, nP);
      var modes = FromBytes<MODE_INFO>(all, 8 + nP*pSz, nM);
      PATH_INFO[] cur; MODE_INFO[] curM; QueryActive(out cur, out curM);   // re-carimba adapterId (LUID muda a cada boot; assume 1 GPU)
      if (cur.Length > 0) { LUID luid = cur[0].src.adapterId;
        for(int i=0;i<paths.Length;i++){ paths[i].src.adapterId=luid; paths[i].tgt.adapterId=luid; }
        for(int i=0;i<modes.Length;i++){ modes[i].adapterId=luid; } }
      return SetDisplayConfig((uint)paths.Length, paths, (uint)modes.Length, modes,
        SDC_APPLY | SDC_USE_SUPPLIED | SDC_SAVE_DB | SDC_ALLOW_CHANGES);
    }
    public static string Describe(string file) {
      byte[] all = File.ReadAllBytes(file);
      int nP = BitConverter.ToInt32(all,0); int nM = BitConverter.ToInt32(all,4);
      int pSz = Marshal.SizeOf(typeof(PATH_INFO));
      var paths = FromBytes<PATH_INFO>(all, 8, nP);
      var modes = FromBytes<MODE_INFO>(all, 8 + nP*pSz, nM);
      string s = nP + " tela(s): ";
      for (int i=0;i<paths.Length;i++){ var idx = paths[i].src.modeInfoIdx;
        if (idx < modes.Length) { var sm = modes[idx].mode.sourceMode;
          s += sm.width + "x" + sm.height + (sm.position.x==0 && sm.position.y==0 ? "(principal) " : " "); } }
      return s.Trim();
    }
    public static int ActiveCount() { PATH_INFO[] p; MODE_INFO[] m; QueryActive(out p, out m); return p.Length; }
  }
}

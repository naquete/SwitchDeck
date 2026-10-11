using System.Windows.Media;

namespace SwitchDeck.UI
{
    // Native CLR properties avoid PowerShell's PSObject wrappers in WPF bindings.
    public sealed class Choice
    {
        public string Name { get; set; }
        public string Short { get; set; }
        public string Id { get; set; }
        public string Label { get; set; }
        public string Summary { get; set; }
        public override string ToString()
        {
            if (Short != null) return Short;
            if (Label != null) return Label;
            if (Summary != null) return Summary;
            if (Name != null) return Name;
            return "";
        }
    }

    public sealed class Tile
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public ImageSource Image { get; set; }
        public string Ring { get; set; }
        public string Status { get; set; }
        public string StatusColor { get; set; }
        public string ActiveVisibility { get; set; }
        public string NewVisibility { get; set; }
        public string ActionVisibility { get; set; }
        public string Description { get; set; }
    }
}

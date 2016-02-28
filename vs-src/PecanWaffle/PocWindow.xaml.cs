using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;

namespace PecanWaffle {
    /// <summary>
    /// Interaction logic for PocWindow.xaml
    /// </summary>
    public partial class PocWindow : Window {
        public string TemplatePathOrUrl { get; private set; }
        public string TemplateBranch { get; private set; }
        public string TemplateName { get; private set; }
        public PocWindow() {
            InitializeComponent();
        }

        private void ButtonOkClick(object sender, RoutedEventArgs e) {
            TemplateName = textTemplateName.Text;
            TemplatePathOrUrl = textPath.Text;
            TemplateBranch = textBranch.Text;

            this.DialogResult = true;
            this.Close();
        }

        private void ButtonCancelClick(object sender, RoutedEventArgs e) {
            this.DialogResult = false;
            this.Close();
        }
    }
}

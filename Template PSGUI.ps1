<#
.SYNOPSIS
    Modèle pour application PowerShell WinForms autonome.
.DESCRIPTION
    Structure de script pour une application graphique (GUI) PowerShell.
    Inclut le masquage de la console, l'identification de l'application
    pour la barre des tâches et l'intégration de l'icône en Base64.
.NOTES
    Auteur: [Votre Nom]
    Version: 1.1
#>

#-----------------------------------------------------------------------------------
#region Identification de l'Application (AppUserModelID)
# Définit l'identité de l'application. DOIT être exécuté en premier.
# Associe un ID unique au processus (AppUserModelID) pour que la barre des tâches
# le traite comme une application indépendante (et non PowerShell).
#-----------------------------------------------------------------------------------
$AppID = "MaSociete.MonOutil.v1" # À personnaliser pour chaque projet
$AppIDCode = @"
using System.Runtime.InteropServices;
namespace Win32 {
    public class AppUserModelID {
        [DllImport("shell32.dll", SetLastError=true)]
        public static extern int SetCurrentProcessExplicitAppUserModelID(
            [MarshalAs(UnmanagedType.LPWStr)] string AppID);
    }
}
"@
Add-Type -TypeDefinition $AppIDCode
[Win32.AppUserModelID]::SetCurrentProcessExplicitAppUserModelID($AppID) | Out-Null
#endregion

#-----------------------------------------------------------------------------------
#region Chargement des Assemblages .NET
# Chargement anticipé des bibliothèques WinForms et Drawing
# pour permettre l'utilisation de [MessageBox] ou d'autres classes
# dans la section des prérequis.
#-----------------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
#endregion

#-----------------------------------------------------------------------------------
#region Vérifications des Prérequis (Exemple)
# Emplacement pour valider les dépendances (ex: exécutables, .NET).
#-----------------------------------------------------------------------------------
# If (!(Test-Path -Path "$Env:SystemRoot\System32\makecab.exe")) {
#     [void][System.Windows.Forms.MessageBox]::Show("MakeCAB est introuvable.", "Erreur", "0", "16")
#     Exit
# }
#endregion

#-----------------------------------------------------------------------------------
#region Masquage de la Console
# Fonction pour masquer la fenêtre de la console (y compris Windows Terminal).
# NOTE : L'analyse de processus (Get-Process) peut être détectée par les EDR.
#-----------------------------------------------------------------------------------
Function Hide-ConsoleWindow {
    $ShowWindowAsyncCode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $ShowWindowAsync = Add-Type -MemberDefinition $ShowWindowAsyncCode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $hwnd = (Get-Process -PID $pid).MainWindowHandle
    if ($hwnd -ne [System.IntPtr]::Zero) {
        $ShowWindowAsync::ShowWindowAsync($hwnd, 0) | Out-Null
    }
    else {
        $UniqueWindowTitle = New-Guid
        $Host.UI.RawUI.WindowTitle = $UniqueWindowTitle
        Start-Sleep -Milliseconds 50
        $TerminalProcess = (Get-Process | Where-Object { $_.MainWindowTitle -eq $UniqueWindowTitle })
        $hwnd = $TerminalProcess.MainWindowHandle
        if ($hwnd -ne [System.IntPtr]::Zero) {
            $ShowWindowAsync::ShowWindowAsync($hwnd, 0) | Out-Null
        }
    }
}
Hide-ConsoleWindow # Masque la console au démarrage
#endregion

#-----------------------------------------------------------------------------------
#region Classes C# personnalisées (Optionnel)
# Emplacement pour charger d'autres classes C# (ex: VistaProgressBar).
#-----------------------------------------------------------------------------------
# $code = @"
# namespace MonEspaceDeTravail {
#     // public class MaClassePerso { ... }
# }
# "@
# Add-Type -TypeDefinition $code -ReferencedAssemblies System.Windows.Forms, System.Drawing
#endregion

#-----------------------------------------------------------------------------------
#region Données Embarquées (Icône Base64)
# Stockage de l'icône de l'application en Base64.
#
<#
    --- OUTILS POUR CRÉER LA CHAÎNE BASE64 ---
    
    --- Outil 1: Extraire un .ico depuis un .exe ou .dll ---
    # (À exécuter séparément pour obtenir le fichier .ico)
    
    Add-Type -AssemblyName System.Drawing
    $IconExtractorCode = @"
    using System;
    using System.Drawing;
    using System.Runtime.InteropServices;
    namespace Utility.Extractor {
        public class IconExtractor {
            [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
            private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);
            public static Icon Extract(string file, int number) {
                IntPtr large; IntPtr small;
                ExtractIconEx(file, number, out large, out small, 1);
                try { return Icon.FromHandle(large); } catch { return null; }
            }
        }
    }
"@
    Add-Type -TypeDefinition $IconExtractorCode -ReferencedAssemblies System.Drawing

    # --- À CONFIGURER ---
    # $sourceFile = "$Env:SystemRoot\System32\cabview.dll"
    # $iconIndex  = 0 # 0 = 1ère icône, 1 = 2ème, etc.
    # $outputFile = "C:\Temp\MonIcone.ico"
    # --------------------
    
    # $icon = [Utility.Extractor.IconExtractor]::Extract($sourceFile, $iconIndex)
    # if ($icon) {
    #     $stream = New-Object System.IO.FileStream($outputFile, "Create")
    #     $icon.Save($stream); $stream.Close(); $icon.Dispose()
    #     Write-Host "Icône extraite avec succès: $outputFile"
    # } else { Write-Error "Extraction impossible." }

    --- Outil 2: Convertir le .ico en Base64 ---
    # (Une fois que vous avez le .ico de l'Outil 1)
    
    # [Convert]::ToBase64String([IO.File]::ReadAllBytes($outputFile)) | Set-Clipboard
    # Write-Host "Chaîne Base64 copiée dans le presse-papiers."
#>
#-----------------------------------------------------------------------------------

$base64Icon = "AAABAAoAEBAQAAEABAAoAQAApgAAABAQAAABAAgAaAUAAM4B..." # <-- COLLEZ VOTRE CHAÎNE D'ICÔNE ICI
#endregion

#-----------------------------------------------------------------------------------
#region Initialisation du Formulaire Principal
# Activation des styles visuels et création de la fenêtre principale.
#-----------------------------------------------------------------------------------
[Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Template PSGUI"
$form.Size = New-Object System.Drawing.Size(1000, 600)
$form.StartPosition = "CenterScreen"
$form.ShowInTaskbar = $True

# Verrouillage de la taille de la fenêtre
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $False
$form.MinimizeBox = $True

# Charge l'icône depuis la chaîne Base64 et l'assigne au formulaire.
Try {
    $iconBytes = [System.Convert]::FromBase64String($base64Icon)
    $stream = [System.IO.MemoryStream]::new($iconBytes)
    $form.Icon = New-Object System.Drawing.Icon($stream)
    $stream.Close()
}
Catch {
    Write-Warning "Échec du chargement de l'icône Base64. $_"
}
#endregion

#-----------------------------------------------------------------------------------
#region Ajout des Contrôles
# Définition et ajout de tous les éléments graphiques (boutons, labels...).
#-----------------------------------------------------------------------------------
$button_OK = New-Object System.Windows.Forms.Button
$button_OK.Text = "OK"

# Centre le bouton horizontalement
$buttonY = 520 
$buttonX = ($form.ClientSize.Width - $button_OK.Width) / 2
$button_OK.Location = New-Object System.Drawing.Point($buttonX, $buttonY)
 
$form.Controls.Add($button_OK)
#endregion

#-----------------------------------------------------------------------------------
#region Logique des Événements
# Assignation des actions aux contrôles (clics de bouton, etc.).
#-----------------------------------------------------------------------------------
$button_OK.Add_Click({
    $form.Close()
})
#endregion

#-----------------------------------------------------------------------------------
#region Lancement de l'Application
# Affiche le formulaire à l'utilisateur et attend sa fermeture.
#-----------------------------------------------------------------------------------
[void]$form.ShowDialog()

# Fin du script

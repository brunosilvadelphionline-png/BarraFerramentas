' Inicia o tray_menu.pyw silenciosamente (sem janela de console).
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
appDir = fso.GetParentFolderName(WScript.ScriptFullName)
sh.CurrentDirectory = appDir
sh.Run "pythonw """ & appDir & "\tray_menu.pyw""", 0, False

Add-Type -AssemblyName PresentationFramework
[XML]$form = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="UninstallSoftware" Height="482.5" Width="800" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Grid>
        <Label Content="Enter ServerName" HorizontalAlignment="Left" Margin="42,21,0,0" VerticalAlignment="Top" Height="29" Width="114"/>
        <TextBox Name="Srvtxtbx" HorizontalAlignment="Left" Height="25" Margin="161,25,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="211"/>
        <TextBlock Name="Outtxtbx" HorizontalAlignment="Left" Margin="385,10,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Height="366" Width="387" Background="#FF292626" Foreground="#FF2DD635" FontSize="14"><Run Text="Output Console"/></TextBlock>
        <Button Name="WMIUninstbtn" Content="Uninstall Using WMI" HorizontalAlignment="Left" Margin="59,198,0,0" VerticalAlignment="Top" Width="232" Height="38"/>
        <Button Name="PkgUninstallbtn" Content="Uninstall Using MSI Package" HorizontalAlignment="Left" Margin="59,241,0,0" VerticalAlignment="Top" Width="232" Height="40"/>
        <Button Name="Uninstallstringbtn" Content="Uninstall using Registry" HorizontalAlignment="Left" Margin="59,286,0,0" VerticalAlignment="Top" Width="232" RenderTransformOrigin="0.083,-0.2" Height="43"/>
        <TextBox Name="Softwrtxtbx" HorizontalAlignment="Left" Height="22" Margin="161,67,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="211"/>
        <Label Content="Software Name" HorizontalAlignment="Left" Margin="42,63,0,0" VerticalAlignment="Top" Width="104"/>
        <Button Name="testbtn" Content="Test Connection / Software" HorizontalAlignment="Left" Margin="59,157,0,0" VerticalAlignment="Top" Width="232" Height="36"/>
        <Button Name="copybtn" Content="Copy Output" HorizontalAlignment="Left" Margin="59,334,0,0" VerticalAlignment="Top" Width="232" Height="42" RenderTransformOrigin="0.514,0.869"/>
        <CheckBox Name="Rebootchkbx" Content="Reboot?" HorizontalAlignment="Left" Margin="85,122,0,0" VerticalAlignment="Top"/>
        <Label Content="Please wait when you click and button is highlighted light blue.&#xD;&#xA;PowerShell is working in background." HorizontalAlignment="Left" Margin="42,392,0,0" VerticalAlignment="Top" Width="404" Height="51" Foreground="#FFD12626" FontSize="14"/>

 </Grid>
</Window>
"@

$NR = (New-Object System.Xml.XmlNodeReader $form)
$window = [Windows.Markup.XamlReader]::Load($NR)

$inputbx = $window.FindName('Srvtxtbx')
$testbtn = $window.FindName('testbtn')
$WMibtn = $window.FindName('WMIUninstbtn')
$pkgbtn = $window.FindName('PkgUninstallbtn')
$strbtn = $window.FindName('Uninstallstringbtn')
$outbx =  $window.FindName('Outtxtbx')
$softbx = $window.FindName('Softwrtxtbx')
$chkbx = $window.FindName('Rebootchkbx')
$copybtn = $window.FindName('copybtn')

$ErrorActionPreference = "Ignore"
[bool]$exist

function WMIUninstall{

         $software = Get-WmiObject Win32_Product -ComputerName $inputbx.Text | where{$_.Name -like "*$($softbx.Text)*"}
    
    
        #$outbx.Text += "`n$($softbx.Text) software found on $($Inputbx.Text)"
        #$outbx.Text += "`nUninstalling software.. pls wait"
    
        foreach($s in $software){
               $outbx.Text += "`nUninstalling $($s.name).. pls wait"
               $outbx.Text += "`n**********************************************`n`n"

               $s= Get-WmiObject Win32_Product -ComputerName $inputbx.Text | where{$_.Name -eq "$($s.Name)"}
               $s.Uninstall()
               if($s){
                   $outbx.Text += "`nSoftware failed to Uninstall..please try different method"
                   $outbx.Text += "`nIf server was rebooted after software uninstall.. please Click on TEST button again"
               }
               else{
                $outbx.Text += "`nSoftware Uninstalled successfully"

                if($chkbx.IsChecked -eq $true){
                    ServerReboot
                }
             }
        
      
        }
    
    
    
}

function PackageUninstall{
   
    $prdcts = Get-CimInstance Win32_Product -ComputerName $($inputbx.Text) | where{$_.Name -like "*$($softbx.Text)*"}

    Invoke-Command -ComputerName $inputbx.Text -ArgumentList $prdcts -ScriptBlock{
       param($products)
       
       foreach($product in $products){
          Get-Package $product.Name | Uninstall-Package
       }

    }

    $prdcts = Get-CimInstance Win32_Product -ComputerName $($inputbx.Text) | where{$_.Name -like "*$($softbx.Text)*"}

    if($prdcts){
             $outbx.Text += "`nProduct failed to uninstall.. If the server rebooted post uninstall"
            $outbx.Text += "`nclick on TEST button to check the status again"
            $outbx.Text += "Or use different method to uninstall"
    }

    else{
              $outbx.Text += "`nProduct Uninstalled Successfully"
              if($chkbx.IsChecked -eq $true){
                ServerReboot
            }
        }


}

function StringUninstall{
    
    #$products = Get-CimInstance Win32_Product -ComputerName $($inputbx.Text) | where{$_.Name -like "*$($softbx.Text)*"}
    $strbtn.Background = "Red"
    $products = Get-WmiObject Win32_Product -ComputerName $inputbx.Text | where{$_.Name -like "*$($softbx.Text)*"}

   

    Invoke-Command -ComputerName $inputbx.Text -ArgumentList $products -ScriptBlock{
        param(
            $products
        )

        foreach($product in $products){
            $soft = $product.Name
            $32bit = get-itemproperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | Select-Object DisplayName, DisplayVersion, UninstallString, PSChildName | Where-Object { $_.DisplayName -match "^*$soft*"}
            $64bit = get-itemproperty 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | Select-Object DisplayName, DisplayVersion, UninstallString, PSChildName | Where-Object { $_.DisplayName -match "^*$soft*"}
            if($32bit){

                #$outbx.Text += "`nUninstalling $Product"
                $uninst = $32bit.UninstallString
                $uninst = (($uninst -split ' ')[1] -replace '/I','/X') + ' /q'
                Start-Process msiexec.exe -ArgumentList $uninst -Wait
           }
   
           if($64bit){
               #$outbx.Text += "`nUninstalling $Product"
               $uninst = $32bit.UninstallString
               $uninst = (($uninst -split ' ')[1] -replace '/I','/X') + ' /q'
               Start-Process msiexec.exe -ArgumentList $uninst -Wait
           }
        }
        
        
    }
    
 
    


    $products = Get-CimInstance Win32_Product -ComputerName $($inputbx.Text) | where{$_.Name -like "*$($softbx.Text)*"}

    if($products){
        $outbx.Text += "`nSoftware Uninstall failed"
    }
    else{
        $Outbx.Text += "`nSoftware uninstall Completed"

        if($chkbx.IsChecked -eq $true){
             ServerReboot
         }
    }

   $strbtn.Background = "#FFDDDDDD"
}

function ServerReboot{
    $outbx.Text += "`nInitiating reboot $($Inputbx.Text)"
    sleep 5

    Restart-Computer -ComputerName $($Inputbx.Text) -Force
}

Function Test-Connectivity{
        if(($inputbx.Text) -and ($softbx.Text)){
            
           if(Test-Connection $inputbx.Text -count 1 -Quiet){
             $outbx.Text = "`n$($inputbx.Text) Server is pinging`n"
             $soft = $softbx.Text
             $software = Get-WmiObject Win32_Product -ComputerName $inputbx.Text | where{$_.Name -like "*$soft*"}
        
                if($software){
                    $outbx.Text += "`nBelow software with name $($softbx.Text) found on $($Inputbx.Text)"
                    $outbx.Text += "`n**********************************************`n`n"
                    $outbx.Text += $software.Name
                    $outbx.Text += "`n**********************************************`n"
                    return $true
                }

                else{
                   $outbx.Text += "`n$($softbx.Text) software not found on $($Inputbx.Text)"
                   $outbx.Text += "`nMake sure remote server is not using different authentication method"
                   return $false
                }
          }

          else{
              $outbx.Text = "$($inputbx.Text) Connection Failed"
          }

        }

        else{
            $outbx.Text = "Server / Software Name Can't be empty"
        }
          
          
  }


    $testbtn.Add_Click({
         $outbx.Text = ""
         Test-Connectivity
         
    })
    $WMibtn.Add_Click({
         $outbx.Text = "" 
         $outbx.Text = "`nWMI Method selected to Uninstall Software"
         $check = Test-Connectivity

         if($check){WMIUninstall}
    })

    $pkgbtn.Add_Click({
         $outbx.Text = ""
         $check = Test-Connectivity
         if($check){PackageUninstall}
    })

    $strbtn.Add_Click({
        $outbx.Text = ""
        #$strbtn.Background.Color = "Red"
        $check = Test-Connectivity
        if($check){StringUninstall}
    })
    
    $copybtn.Add_Click({
       Set-Clipboard -Value $outbx.Text
       $outbx.Text = "`nOutput is copied to clipboard"
    })



$window.ShowDialog()
   
 
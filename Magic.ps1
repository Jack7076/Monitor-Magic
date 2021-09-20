
#  $$\      $$\                     $$\   $$\                               $$\      $$\                     $$\           
#  $$$\    $$$ |                    \__|  $$ |                              $$$\    $$$ |                    \__|          
#  $$$$\  $$$$ | $$$$$$\  $$$$$$$\  $$\ $$$$$$\    $$$$$$\   $$$$$$\        $$$$\  $$$$ | $$$$$$\   $$$$$$\  $$\  $$$$$$$\ 
#  $$\$$\$$ $$ |$$  __$$\ $$  __$$\ $$ |\_$$  _|  $$  __$$\ $$  __$$\       $$\$$\$$ $$ | \____$$\ $$  __$$\ $$ |$$  _____|
#  $$ \$$$  $$ |$$ /  $$ |$$ |  $$ |$$ |  $$ |    $$ /  $$ |$$ |  \__|      $$ \$$$  $$ | $$$$$$$ |$$ /  $$ |$$ |$$ /      
#  $$ |\$  /$$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$\ $$ |  $$ |$$ |            $$ |\$  /$$ |$$  __$$ |$$ |  $$ |$$ |$$ |      
#  $$ | \_/ $$ |\$$$$$$  |$$ |  $$ |$$ |  \$$$$  |\$$$$$$  |$$ |            $$ | \_/ $$ |\$$$$$$$ |\$$$$$$$ |$$ |\$$$$$$$\ 
#  \__|     \__| \______/ \__|  \__|\__|   \____/  \______/ \__|            \__|     \__| \_______| \____$$ |\__| \_______|
#                                                                                                  $$\   $$ |              
#                                                                                                  \$$$$$$  |              
#                                                                                                   \______/               
#
$makor_service_url = ""
#Authentication String should be user:pass in base64
$authentication_string = ""

Write-Output $authentication_string

$most_recent_monitor = ""
 
 function Decode {
     If ($args[0] -is [System.Array]) {
         [System.Text.Encoding]::ASCII.GetString($args[0])
     }
     Else {
         "Not Found"
     }
 }

function submit_monitor ($man, $serial, $prID, $friendlyname, $wkofman, $yrofman, $notes) {
    $xmlSettings = New-Object System.Xml.XmlWriterSettings
    $xmlSettings.Indent = $true
    $xmlSettings.IndentChars = "    "
    $xmlSettings.OmitXmlDeclaration = $true

    $tmp_file = $env:temp+"\monitor_magic_temp.xml"

    $xmlWriter = [System.Xml.XmlWriter]::Create($tmp_file, $xmlSettings)

    $xmlWriter.WriteStartDocument()
    
    $xmlWriter.WriteStartElement("root")
    $xmlWriter.WriteStartElement("audit")
    $xmlWriter.WriteStartElement("components")
    $xmlWriter.WriteAttributeString("name", "Monitor")

    $xmlWriter.WriteStartElement("component")
    $xmlWriter.WriteAttributeString("name", "Manufacturer")
    $xmlWriter.WriteAttributeString("type", "string")
    $xmlWriter.WriteString($man.Trim([char]0))
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteStartElement("component")
    $xmlWriter.WriteAttributeString("name", "ProductName")
    $xmlWriter.WriteAttributeString("type", "string")
    $xmlWriter.WriteString($friendlyname.Trim([char]0))
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteStartElement("component")
    $xmlWriter.WriteAttributeString("name", "Serial")
    $xmlWriter.WriteAttributeString("type", "string")
    $xmlWriter.WriteString($serial.Trim([char]0))
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteStartElement("component")
    $xmlWriter.WriteAttributeString("name", "Manufacturer")
    $xmlWriter.WriteAttributeString("type", "string")
    $xmlWriter.WriteString($man.Trim([char]0))
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteStartElement("component")
    $xmlWriter.WriteAttributeString("name", "AssetTag")
    $xmlWriter.WriteAttributeString("type", "string")
    $xmlWriter.WriteString("10198")
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteStartElement("component")
    $xmlWriter.WriteAttributeString("name", "WeekOfManafacture")
    $xmlWriter.WriteAttributeString("type", "string")
    $xmlWriter.WriteString($wkofman.Trim([char]0))
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteStartElement("component")
    $xmlWriter.WriteAttributeString("name", "YearOfManafacture")
    $xmlWriter.WriteAttributeString("type", "string")
    $xmlWriter.WriteString($yrofman.Trim([char]0))
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteStartElement("component")
    $xmlWriter.WriteAttributeString("name", "Notes")
    $xmlWriter.WriteAttributeString("type", "string")
    $xmlWriter.WriteString($notes.Trim([char]0))
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteEndElement()
    $xmlWriter.WriteEndElement()
    $xmlWriter.WriteEndElement()

    $xmlWriter.WriteEndDocument()
    $xmlWriter.Flush()
    $xmlWriter.Close()

    $xmlString = [Convert]::ToBase64String([IO.File]::ReadAllBytes($tmp_file))
    #Remove-Item $tmp_file
    $json_body = @{
        'serial_number' = $serial.Trim([char]0)
        'asset_report' = @{
            'report' = $xmlString.Trim([char]0)
        }
    }

    $json_body = $json_body | ConvertTo-Json

    $headers = @{}
    $headers.Add('Authorization', "basic $authentication_string")
    $headers.Add('Content-Type', "application/json")
    
    $request = Invoke-WebRequest -Uri ($makor_service_url+"/api/diagnostics/report") -Headers $headers -Method Post -Body $json_body

    #$request = Invoke-WebRequest -Uri ("https://requestbin.net/r/1wql18h4") -Headers $headers -Method Post -Body $json_body

    $request

    Exit

}


function check_for_new_monitors {
    $monitor_list = Get-WmiObject WmiMonitorID -Namespace root\wmi
    ForEach($display in $monitor_list) {
        $new_display = 1
        ForEach($original_display in $inital_monitors) {
            if((Decode $display.SerialNumberID -notmatch 0) -eq $original_display.Serial){
                $new_display = 0
            }
        }
        if($new_display) {
            # New Monitor Detected
            $disp_serial = Decode $display.SerialNumberID -notmatch 0
            $disp_manufacture = Decode $display.ManufacturerName -notmatch 0
            $disp_productID = Decode $display.ProductCodeID -notmatch 0
            $disp_username = Decode $display.UserFriendlyName -notmatch 0
            $disp_wkofman = Decode $display.WeekOfManufacture -notmatch 0
            $disp_yrofman = Decode $display.YearOfManufacture -notmatch 0

            Write-Warning "Detected New Monitor"
            Write-Output "Display Manufacture: $disp_manufacture"
            Write-Output "Display Product ID: $disp_productID"
            Write-Output "Display Serial #: $disp_serial"
            Write-Output "Display Friendly Name: $disp_username"
            Write-Output "Display Week of Manufacture: $disp_wkofman"
            Write-Output "Display Year of Manufacture: $disp_yrofman"

            $notes = Read-Host -Prompt 'Enter notes, to cancel entry enter "c"'

            if($notes -eq "c"){
                Write-Warning "Canceled New Monitor Entry"
                $exit_cond = Read-Host -Prompt 'To Re-Start Monitor detection press enter; otherwise type exit and press enter to exit the program'
                if ( $exit_cond -eq "exit" ) {
                    Exit
                }
                return
            }
            submit_monitor $disp_manufacture $disp_serial $disp_productID $disp_username $disp_wkofman $disp_yrofman $notes
        }

    }
}

function display_ready_state {
    echo ""
    echo "--------------------------------------------------------------------"
    echo "--------------      Ready to detect new monitor   ------------------"
    echo "--------------------------------------------------------------------"
    echo ""
}

function detect_monitors {
    while (1){
        check_for_new_monitors
    }
}

echo ""
echo "--------------------------------------------------------------------"
echo "--------------      Detecting Connected Monitors  ------------------"
echo "--------------------------------------------------------------------"
echo ""
 
 $Monitors = Get-WmiObject WmiMonitorID -Namespace root\wmi

 $inital_monitors = @()
    
 ForEach ($Monitor in $Monitors) {
    $row = "" | Select Manufacture,Name,Serial,Product_Code
    $row.Manufacture = Decode $Monitor.ManufacturerName -notmatch 0
    $row.Name = Decode $Monitor.UserFriendlyName -notmatch 0
    $row.Serial = Decode $Monitor.SerialNumberID -notmatch 0
    $row.Product_Code = Decode $Monitor.ProductCodeID -notmatch 0
    $inital_monitors += $row
 }

 $inital_monitors | Format-Table

display_ready_state
detect_monitors
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Find-Ast {
    <#
    .EXTERNALHELP ..\PowerShellEditorServices.Commands-help.xml
    #>
    [CmdletBinding(PositionalBinding=$false, DefaultParameterSetName='FilterScript')]
    param(
        [Parameter(Position=0, ParameterSetName='FilterScript')]
        [ValidateNotNullOrEmpty()]
        [scriptblock]
        $FilterScript = { $true },

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName='FilterScript')]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Language.Ast]
        $Ast,

        [Parameter(ParameterSetName='FilterScript')]
        [switch]
        $Before,

        [Parameter(ParameterSetName='FilterScript')]
        [switch]
        $Family,

        [Parameter(ParameterSetName='FilterScript')]
        [Alias('Closest', 'F')]
        [switch]
        $First,

        [Parameter(ParameterSetName='FilterScript')]
        [Alias('Furthest')]
        [switch]
        $Last,

        [Parameter(ParameterSetName='FilterScript')]
        [Alias('Parent')]
        [switch]
        $Ancestor,

        [Parameter(ParameterSetName='FilterScript')]
        [switch]
        $IncludeStartingAst,

        [Parameter(ParameterSetName='AtCursor')]
        [switch]
        $AtCursor
    )
    begin {
        # InvokeWithContext method is PS4+, but it's significantly faster for large files.
        if ($PSVersionTable.PSVersion.Major -ge 4) {

            $variableType = [System.Management.Automation.PSVariable]
            function InvokeWithContext {
                param([scriptblock]$Filter, [System.Management.Automation.Language.Ast]$DollarUnder)

                return $Filter.InvokeWithContext(
                        <# functionsToDefine: #> $null,
                        <# variablesToDefine: #> [Activator]::CreateInstance($variableType, @('_', $DollarUnder)),
                        <# args:              #> $aAst)
            }
        } else {
            $FilterScript = [scriptblock]::Create($FilterScript.ToString())
            function InvokeWithContext {
                param([scriptblock]$Filter, [System.Management.Automation.Language.Ast]$DollarUnder)

                return $DollarUnder | & { process { $Filter.InvokeReturnAsIs($DollarUnder) } }
            }
        }
        # Get all children or ancestors.
        function GetAllFamily {
            param($Start)

            if ($Before.IsPresent) {
                $parent = $Start
                for ($parent; $parent = $parent.Parent) { $parent }
                return
            }
            return $Start.FindAll({ $true }, $true)
        }
        # Get all asts regardless of structure, in either direction from the starting ast.
        function GetAllAsts {
            param($Start)

            $predicate = [Func[System.Management.Automation.Language.Ast,bool]]{
                $args[0] -ne $Ast
            }

            $topParent = Find-Ast -Ast $Start -Ancestor -Last -IncludeStartingAst
            if (-not $topParent) { $topParent = $Start }

            if ($Before.IsPresent) {
                # Need to store so we can reverse the collection.
                $result = [Linq.Enumerable]::TakeWhile(
                    $topParent.FindAll({ $true }, $true),
                    $predicate) -as [System.Management.Automation.Language.Ast[]]

                [array]::Reverse($result)
                return $result
            }
            return [Linq.Enumerable]::SkipWhile(
                $topParent.FindAll({ $true }, $true),
                $predicate)
        }
    }
    process {
        if ($Ancestor.IsPresent) {
            $Family = $Before = $true
        }
        $context = $psEditor.GetEditorContext()

        if (-not $Ast -and $context) {
            $Ast = $context.CurrentFile.Ast
        }
        switch ($PSCmdlet.ParameterSetName) {
            AtCursor {
                $cursorLine     = $context.CursorPosition.Line - 1
                $cursorColumn   = $context.CursorPosition.Column - 1
                $cursorOffset   = $Ast.Extent.Text |
                    Select-String "(.*\r?\n){$cursorLine}.{$cursorColumn}" |
                    ForEach-Object { $PSItem.Matches.Value.Length }

                # yield
                Find-Ast -Last {
                    $cursorOffset -ge $PSItem.Extent.StartOffset -and
                    $cursorOffset -le $PSItem.Extent.EndOffset
                }
            }
            FilterScript {
                if (-not $Ast) { return }

                # Check if we're trying to get the top level ancestor when we're already there.
                if ($Before.IsPresent -and
                    $Family.IsPresent -and
                    $Last.IsPresent   -and -not
                    $Ast.Parent       -and
                    $Ast -is [System.Management.Automation.Language.ScriptBlockAst])
                    { return $Ast }

                if ($Family.IsPresent) {
                    $asts = GetAllFamily $Ast
                } else {
                    $asts = GetAllAsts $Ast
                }
                # Check the first ast to see if it's our starting ast, unless
                $checkFirstAst = -not $IncludeStartingAst
                foreach ($aAst in $asts) {
                    if ($checkFirstAst) {
                        if ($aAst -eq $Ast) {
                            $checkFirstAst = $false
                            continue
                        }
                    }
                    $shouldReturn = InvokeWithContext $FilterScript $aAst

                    if (-not $shouldReturn) { continue }

                    # Return first, last, both, or all depending on the combination of switches.
                    if (-not $Last.IsPresent) {
                        $aAst # yield
                        if ($First.IsPresent) { break }
                    } else {
                        $lastMatch = $aAst
                        if ($First.IsPresent) {
                            $aAst # yield
                            $First = $false
                        }
                    }
                }
                # yield
                if ($Last.IsPresent) { return $lastMatch }
            }
        }
    }
}

# SIG # Begin signature block
# MIInpQYJKoZIhvcNAQcCoIInljCCJ5ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAItklfWteKH2i/
# HFdzPlev2c8mkTjAIWWicaXP36bs9qCCDYUwggYDMIID66ADAgECAhMzAAACzfNk
# v/jUTF1RAAAAAALNMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjIwNTEyMjA0NjAyWhcNMjMwNTExMjA0NjAyWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDrIzsY62MmKrzergm7Ucnu+DuSHdgzRZVCIGi9CalFrhwtiK+3FIDzlOYbs/zz
# HwuLC3hir55wVgHoaC4liQwQ60wVyR17EZPa4BQ28C5ARlxqftdp3H8RrXWbVyvQ
# aUnBQVZM73XDyGV1oUPZGHGWtgdqtBUd60VjnFPICSf8pnFiit6hvSxH5IVWI0iO
# nfqdXYoPWUtVUMmVqW1yBX0NtbQlSHIU6hlPvo9/uqKvkjFUFA2LbC9AWQbJmH+1
# uM0l4nDSKfCqccvdI5l3zjEk9yUSUmh1IQhDFn+5SL2JmnCF0jZEZ4f5HE7ykDP+
# oiA3Q+fhKCseg+0aEHi+DRPZAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQU0WymH4CP7s1+yQktEwbcLQuR9Zww
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzQ3MDUzMDAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AE7LSuuNObCBWYuttxJAgilXJ92GpyV/fTiyXHZ/9LbzXs/MfKnPwRydlmA2ak0r
# GWLDFh89zAWHFI8t9JLwpd/VRoVE3+WyzTIskdbBnHbf1yjo/+0tpHlnroFJdcDS
# MIsH+T7z3ClY+6WnjSTetpg1Y/pLOLXZpZjYeXQiFwo9G5lzUcSd8YVQNPQAGICl
# 2JRSaCNlzAdIFCF5PNKoXbJtEqDcPZ8oDrM9KdO7TqUE5VqeBe6DggY1sZYnQD+/
# LWlz5D0wCriNgGQ/TWWexMwwnEqlIwfkIcNFxo0QND/6Ya9DTAUykk2SKGSPt0kL
# tHxNEn2GJvcNtfohVY/b0tuyF05eXE3cdtYZbeGoU1xQixPZAlTdtLmeFNly82uB
# VbybAZ4Ut18F//UrugVQ9UUdK1uYmc+2SdRQQCccKwXGOuYgZ1ULW2u5PyfWxzo4
# BR++53OB/tZXQpz4OkgBZeqs9YaYLFfKRlQHVtmQghFHzB5v/WFonxDVlvPxy2go
# a0u9Z+ZlIpvooZRvm6OtXxdAjMBcWBAsnBRr/Oj5s356EDdf2l/sLwLFYE61t+ME
# iNYdy0pXL6gN3DxTVf2qjJxXFkFfjjTisndudHsguEMk8mEtnvwo9fOSKT6oRHhM
# 9sZ4HTg/TTMjUljmN3mBYWAWI5ExdC1inuog0xrKmOWVMIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGXYwghlyAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAALN82S/+NRMXVEAAAAA
# As0wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIIJK
# wga/iSAEmqs98xcuwgBqGXwTwWpA2lBHh7HkgP8MMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAVKuO5WkgrRXiORNz3Y+Qs+/CRjT0m9gS9gQt
# 15G6utpSphwvFuchfot0sc0WlItPpNbkfH7Y0KQVmdzn3l9POFpIJzeMU2WiEcYu
# uByfuK7icteZqLAT9d7s/vXM4Cx9Ag9wwVQWaLXBy5ykWEkU1BUdnVzHG9+NtxoM
# suP4ssbbmmVHkc6DEUEs6Xg27tiVqfRwDAhV02UlZgabYHNQbViou4x6rP1WxXKZ
# dT0tJi/pK9ByYyn9JQVEPBj1VVjhPIj4wHo+RkRu860jBWhvL1sTgvmfi3NtSDgd
# rA10hxTcCvHiwuouTmXILl83EIVFGqrS4GLqPGgEn8cBFMW7/qGCFwAwghb8Bgor
# BgEEAYI3AwMBMYIW7DCCFugGCSqGSIb3DQEHAqCCFtkwghbVAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFRBgsqhkiG9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCC5NEWK62MTmOlgM4SDC+dltMoF+Aa6RFGZ
# +6eDC7g7CAIGZDfqoVCBGBMyMDIzMDQyNTIzMjU1MS4yODFaMASAAgH0oIHQpIHN
# MIHKMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjo4QTgyLUUzNEYtOUREQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCEVcwggcMMIIE9KADAgECAhMzAAABwvp9hw5UU0ckAAEA
# AAHCMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTIyMTEwNDE5MDEyOFoXDTI0MDIwMjE5MDEyOFowgcoxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVy
# aWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjhBODItRTM0
# Ri05RERBMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtfEJvPKOSFn3petp9wco29/U
# oJmDDyHpmmpRruRVWBF37By0nvrszScOV/K+LvHWWWC4S9cme4P63EmNhxTN/k2C
# gPnIt/sDepyACSkya4ukqc1sT2I+0Uod0xjy9K2+jLH8UNb9vM3yH/vCYnaJSUqg
# tqZUly82pgYSB6tDeZIYcQoOhTI+M1HhRxmxt8RaAKZnDnXgLdkhnIYDJrRkQBpI
# gahtExtTuOkmVp2y8YCoFPaUhUD2JT6hPiDD7qD7A77PLpFzD2QFmNezT8aHHhKs
# VBuJMLPXZO1k14j0/k68DZGts1YBtGegXNkyvkXSgCCxt3Q8WF8laBXbDnhHaDLB
# hCOBaZQ8jqcFUx8ZJSXQ8sbvEnmWFZmgM93B9P/JTFTF6qBVFMDd/V0PBbRQC2Tc
# tZH4bfv+jyWvZOeFz5yltPLRxUqBjv4KHIaJgBhU2ntMw4H0hpm4B7s6LLxkTsjL
# sajjCJI8PiKi/mPKYERdmRyvFL8/YA/PdqkIwWWg2Tj5tyutGFtfVR+6GbcCVhij
# jy7l7otxa/wYVSX66Lo0alaThjc+uojVwH4psL+A1qvbWDB9swoKla20eZubw7fz
# CpFe6qs++G01sst1SaA0GGmzuQCd04Ue1eH3DFRDZPsN+aWvA455Qmd9ZJLGXuqn
# Bo4BXwVxdWZNj6+b4P8CAwEAAaOCATYwggEyMB0GA1UdDgQWBBRGsYh76V41aUCR
# XE9WvD++sIfGajAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNV
# HR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2Ny
# bC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYI
# KwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0G
# CSqGSIb3DQEBCwUAA4ICAQARdu3dCkcLLPfaJ3rR1M7D9jWHvneffkmXvFIJtqxH
# GWM1oqAh+bqxpI7HZz2MeNhh1Co+E9AabOgj94Sp1seXxdWISJ9lRGaAAWzA873a
# TB3/SjwuGqbqQuAvUzBFCO40UJ9anpavkpq/0nDqLb7XI5H+nsmjFyu8yqX1PMmn
# b4s1fbc/F30ijaASzqJ+p5rrgYWwDoMihM5bF0Y0riXihwE7eTShak/EwcxRmG3h
# +OT+Ox8KOLuLqwFFl1siTeQCp+YSt4J1tWXapqGJDlCbYr3Rz8+ryTS8CoZAU0vS
# HCOQcq12Th81p7QlHZv9cTRDhZg2TVyg8Gx3X6mkpNOXb56QUohI3Sn39WQJwjDn
# 74J0aVYMai8mY6/WOurKMKEuSNhCiei0TK68vOY7sH0XEBWnRSbVefeStDo94UIU
# VTwd2HmBEfY8kfryp3RlA9A4FvfUvDHMaF9BtvU/pK6d1CdKG29V0WN3uVzfYETJ
# oRpjLYFGq0MvK6QVMmuNxk3bCRfj1acSWee14UGjglxWwvyOfNJe3pxcNFOd8Hhy
# p9d4AlQGVLNotaFvopgPLeJwUT3dl5VaAAhMwvIFmqwsffQy93morrprcnv74r5g
# 3ejC39NYpFEoy+qmzLW1jFa1aXE2Xb/KZw2yawqldSp0Hu4VEkjGxFNc+AztIUWw
# mTCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZIhvcNAQEL
# BQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNV
# BAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4X
# DTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDk4aZM
# 57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25PhdgM/9cT8dm
# 95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPFdvWGUNzB
# RMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6GnszrYBb
# fowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBpDco2LXCO
# Mcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50ZuyjLVwIYw
# XE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3EXzTdEonW
# /aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0lBw0gg/w
# EPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1qGFphAXPK
# Z6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ+QuJYfM2
# BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PAPBXbGjfH
# CBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkwEgYJKwYB
# BAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxGNSnPEP8v
# BO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARVMFMwUQYM
# KwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAKBggrBgEF
# BQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBW
# BgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUH
# AQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# L2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG9w0BAQsF
# AAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0xM7U518Jx
# Nj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmCVgADsAW+
# iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449xvNo32X2
# pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wMnosZiefw
# C2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDSPeZKPmY7
# T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2dY3RILLFO
# Ry3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxnGSgkujhL
# mm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+CrvsQWY9af3L
# wUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokLjzbaukz5
# m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL6Xu/OHBE
# 0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggLOMIICNwIB
# ATCB+KGB0KSBzTCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UE
# CxMdVGhhbGVzIFRTUyBFU046OEE4Mi1FMzRGLTlEREExJTAjBgNVBAMTHE1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAMp1N1VLhPMv
# WXEoZfmF4apZlnRUoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTAwDQYJKoZIhvcNAQEFBQACBQDn8jl1MCIYDzIwMjMwNDI1MTkzNTE3WhgPMjAy
# MzA0MjYxOTM1MTdaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAOfyOXUCAQAwCgIB
# AAICBzoCAf8wBwIBAAICEfkwCgIFAOfzivUCAQAwNgYKKwYBBAGEWQoEAjEoMCYw
# DAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0B
# AQUFAAOBgQCKeMvxXqApFMfORGZ9aRj6vpzKoZRTdWEOBa2Ll70YKwuKsPPmmSfa
# 9bbfQg+HiUx9aWpr+y6UBs3QIGIzxhmoT6aj6dp1xRQJAPN5GDS8zXCfKgMkO0mT
# uYe9QSkYcgW60TdLIhVv3axCHvkQ3N7mgc88ZTH8+iMTyaheqe1vlzGCBA0wggQJ
# AgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAk
# BgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABwvp9hw5U
# U0ckAAEAAAHCMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZI
# hvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIHD5LJ8C5KZtSh3maJaKGNH46IsfLOWx
# 78Z/zC7AdbS/MIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgypNgW8fpsMV5
# 7r0F5beUuiEVOVe4BdmaO+e28mGDUBYwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAcL6fYcOVFNHJAABAAABwjAiBCA05TuCAk+Ewu8K
# oUwrKspZFiGPKsA2hoARRHpEohpVmTANBgkqhkiG9w0BAQsFAASCAgBATk9hxDDq
# 1rXZnwRRXS1oOLyOowUMvrTDuhtnxEApJEmiO8FQTfqht/qXQv5LZz+q/D3u/+oa
# xbUZ8Sc/OpUrOaJWk1fkuYvX1f/1y/O8Cd4wwMzo0UyFpcu6/PiV8IPmLkTUqr5R
# 2b9XjsRMmSrum5SKYB4Yjp/v5L9U6AWJl2pETT34ZdE5n7T+vyahvSSZS7wIb9c8
# sQIXCPdsTTzpGrh4lPSMCkpXg8xMa1c6Cb1VwE36WBOas8jp9pW35gXIj7kQ+Y6R
# LT1/R+vq7qjATBc+X5QBdgQsCIKJuqP19Z2cjBnLN6YK85SrCfpnW3dOc76DjEDR
# uaVwslaVWlYYMkXn1lOrpIn+GAksZ7TR62e/zE6Z9bXQk6sZNRLQeM7Vv0gQFXSE
# 2SIglukk0aUS/uGG5GF0knUvTQcOtSAH+4MAoY6x4m8y9gFrn91KOLUVfTxfgyTL
# wYtlVLoMw/oXrUbhwe045z+Ntd7Ak6HJ60CXYQup7Vs/WUhJ9KffVePHn9KemmNB
# +dF/vm9VhchVmUVZPPRSlVJXouvqH/fNDTr7uVkhMqtE280s5JwjiW1rx/TF7O8H
# JW/73of5lac91CuZoYqM3tGVFErze9NO4QqEIsH5q6ze25TB/S3+19zqrYSmce8g
# OFND/OeiqIVRFfFwf0bUQDAgy5iZdAVISQ==
# SIG # End signature block

[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}
$scriptDir = ((Get-ScriptDirectory) + "\")

$importPecanWaffle = (Join-Path -Path $scriptDir -ChildPath 'import-pw.ps1')

# import the module
. $importPecanWaffle

function Ensure-PathExists{
    param([Parameter(Position=0)][System.IO.DirectoryInfo]$path)
    process{
        if($path -ne $null){
            if(-not (Test-Path $path.FullName)){
                New-Item -Path $path.FullName -ItemType Directory
            }
        }
    }
}

Describe 'InternalGet-TemplateVsTemplateZipFile tests'{
    It 'can create the file'{
        #  
        [System.IO.DirectoryInfo]$dest = (Join-Path $TestDrive 'getvstemplate01')
        Ensure-PathExists -path $dest.FullName
        { InternalGet-TemplateVsTemplateZipFile -templatefilepath (Join-Path $dest.FullName 'test.zip') } | should not throw
    }
}

Describe 'InternalGet-PackageStringsFromFile tests'{
    It 'basic test' {
        $testname = 'getpkgsstr01'
        [string]$dest = ([System.IO.DirectoryInfo](Join-Path $TestDrive "$testname\src")).FullName
        Ensure-PathExists -path $dest
        $contents = 
@'
  <ItemGroup>
    <Reference Include="GalaSoft.MvvmLight, Version=5.2.0.37222, Culture=neutral, PublicKeyToken=e7570ab207bcb616, processorArchitecture=MSIL">
      <HintPath>..\..\packages\MvvmLightLibs.5.2.0.0\lib\portable-net45+wp8+wpa81+netcore45+monoandroid1+xamarin.ios10\GalaSoft.MvvmLight.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="GalaSoft.MvvmLight.Extras, Version=5.2.0.37222, Culture=neutral, PublicKeyToken=669f0b5e8f868abf, processorArchitecture=MSIL">
      <HintPath>..\..\packages\MvvmLightLibs.5.2.0.0\lib\portable-net45+wp8+wpa81+netcore45+monoandroid1+xamarin.ios10\GalaSoft.MvvmLight.Extras.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="Microsoft.Practices.ServiceLocation, Version=1.3.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\..\packages\CommonServiceLocator.1.3\lib\portable-net4+sl5+netcore45+wpa81+wp8\Microsoft.Practices.ServiceLocation.dll</HintPath>
      <Private>True</Private>
    </Reference>
  </ItemGroup>
'@
        [string]$testfilepath = (Join-Path $dest 'sample1.txt')
        Create-TestFileAt -path $testfilepath -content $contents

        $packageString = InternalGet-PackageStringsFromFile -files $testfilepath
        $packageString.gettype().fullname | should be 'System.String'
        $packageString | should be '..\..\packages'
    }

    It 'Check packages path when packages.config is in subfolder'{
        $srcfile = 'M:\Data\Dropbox\Personal\pecan-waffle\sean-hoffman\Framework.Mobile\Framework.Mobile.Utility.csproj'

        $contents = 
@'
<?xml version="1.0" encoding="utf-8"?>
<Project ToolsVersion="12.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
    <Reference Include="GalaSoft.MvvmLight, Version=5.2.0.37222, Culture=neutral, PublicKeyToken=e7570ab207bcb616, processorArchitecture=MSIL">
      <HintPath>..\..\packages\MvvmLightLibs.5.2.0.0\lib\portable-net45+wp8+wpa81+netcore45+monoandroid1+xamarin.ios10\GalaSoft.MvvmLight.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <None Include="packages.config" />
    <None Include="Views\packages.config" />
  </ItemGroup>
  <ItemGroup>
  <Import Project="$(MSBuildExtensionsPath32)\Microsoft\Portable\$(TargetFrameworkVersion)\Microsoft.Portable.CSharp.targets" />
  <Import Project="..\..\packages\Xamarin.Forms.2.2.0.31\build\portable-win+net45+wp80+win81+wpa81+MonoAndroid10+MonoTouch10+Xamarin.iOS10\Xamarin.Forms.targets" Condition="Exists('..\..\packages\Xamarin.Forms.2.2.0.31\build\portable-win+net45+wp80+win81+wpa81+MonoAndroid10+MonoTouch10+Xamarin.iOS10\Xamarin.Forms.targets')" />
</Project>
'@

        $testname = 'updatepkgspath04'
        [string]$dest = ([System.IO.DirectoryInfo](Join-Path $TestDrive "$testname\src")).FullName
        Ensure-PathExists -path $dest
        $destfile = (Join-Path $dest 'proj.csproj')
        Create-TestFileAt -path $destfile -content $contents

        $packageString = InternalGet-PackageStringsFromFile -files $destfile
        $packageString.gettype().fullname | should be 'System.String'
        $packageString | should be '..\..\packages'
    }
}

Describe 'Update-PWPackagesPath tests'{
    It 'test 01' {
        $testname = 'updatepkgspath01'
        [string]$dest = ([System.IO.DirectoryInfo](Join-Path $TestDrive "$testname\src")).FullName
        Ensure-PathExists -path $dest
        $contents = 
@'
  <ItemGroup>
    <Reference Include="GalaSoft.MvvmLight, Version=5.2.0.37222, Culture=neutral, PublicKeyToken=e7570ab207bcb616, processorArchitecture=MSIL">
      <HintPath>..\..\packages\MvvmLightLibs.5.2.0.0\lib\portable-net45+wp8+wpa81+netcore45+monoandroid1+xamarin.ios10\GalaSoft.MvvmLight.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="GalaSoft.MvvmLight.Extras, Version=5.2.0.37222, Culture=neutral, PublicKeyToken=669f0b5e8f868abf, processorArchitecture=MSIL">
      <HintPath>..\..\packages\MvvmLightLibs.5.2.0.0\lib\portable-net45+wp8+wpa81+netcore45+monoandroid1+xamarin.ios10\GalaSoft.MvvmLight.Extras.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="Microsoft.Practices.ServiceLocation, Version=1.3.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\..\packages\CommonServiceLocator.1.3\lib\portable-net4+sl5+netcore45+wpa81+wp8\Microsoft.Practices.ServiceLocation.dll</HintPath>
      <Private>True</Private>
    </Reference>
  </ItemGroup>
'@
        [string]$testfilepath = (Join-Path $dest 'sample1.txt')
        Create-TestFileAt -path $testfilepath -content $contents

        $packageString = InternalGet-PackageStringsFromFile -files $testfilepath

        Update-PWPackagesPath -filesToUpdate $testfilepath -solutionRoot ((Get-Item $dest).Parent.Parent.Parent.FullName)

        [System.IO.File]::ReadAllText($testfilepath).Contains('<HintPath>..\..\..\packages\') | Should be $true
        [System.IO.File]::ReadAllText($testfilepath).Contains('<HintPath>..\..\packages\') | Should be $false
    }

    It 'test 02' {
        $testname = 'updatepkgspath02'
        [string]$dest = ([System.IO.DirectoryInfo](Join-Path $TestDrive "$testname\src")).FullName
        Ensure-PathExists -path $dest
        $contents = 
@'
  <ItemGroup>
    <Reference Include="GalaSoft.MvvmLight, Version=5.2.0.37222, Culture=neutral, PublicKeyToken=e7570ab207bcb616, processorArchitecture=MSIL">
      <HintPath>..\..\packages\MvvmLightLibs.5.2.0.0\lib\portable-net45+wp8+wpa81+netcore45+monoandroid1+xamarin.ios10\GalaSoft.MvvmLight.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="GalaSoft.MvvmLight.Extras, Version=5.2.0.37222, Culture=neutral, PublicKeyToken=669f0b5e8f868abf, processorArchitecture=MSIL">
      <HintPath>..\..\packages\MvvmLightLibs.5.2.0.0\lib\portable-net45+wp8+wpa81+netcore45+monoandroid1+xamarin.ios10\GalaSoft.MvvmLight.Extras.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="Microsoft.Practices.ServiceLocation, Version=1.3.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\..\packages\CommonServiceLocator.1.3\lib\portable-net4+sl5+netcore45+wpa81+wp8\Microsoft.Practices.ServiceLocation.dll</HintPath>
      <Private>True</Private>
    </Reference>
  </ItemGroup>
'@
        [string]$testfilepath = (Join-Path $dest 'sample1.txt')
        Create-TestFileAt -path $testfilepath -content $contents

        $packageString = InternalGet-PackageStringsFromFile -files $testfilepath

        Update-PWPackagesPath -filesToUpdate $testfilepath -solutionRoot (((Get-Item $dest).Parent.FullName)+'\')

        [System.IO.File]::ReadAllText($testfilepath).Contains('<HintPath>..\packages\') | Should be $true
        [System.IO.File]::ReadAllText($testfilepath).Contains('<HintPath>..\..\packages\') | Should be $false
    }

    It 'test 03' {
        $testname = 'updatepkgspath03'
        [string]$dest = ([System.IO.DirectoryInfo](Join-Path $TestDrive "$testname\src")).FullName
        Ensure-PathExists -path $dest
        $contents = 
@'
  <ItemGroup>
    <Reference Include="GalaSoft.MvvmLight, Version=5.2.0.37222, Culture=neutral, PublicKeyToken=e7570ab207bcb616, processorArchitecture=MSIL">
      <HintPath>..\..\packages\MvvmLightLibs.5.2.0.0\lib\portable-net45+wp8+wpa81+netcore45+monoandroid1+xamarin.ios10\GalaSoft.MvvmLight.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="GalaSoft.MvvmLight.Extras, Version=5.2.0.37222, Culture=neutral, PublicKeyToken=669f0b5e8f868abf, processorArchitecture=MSIL">
      <HintPath>..\..\packages\MvvmLightLibs.5.2.0.0\lib\portable-net45+wp8+wpa81+netcore45+monoandroid1+xamarin.ios10\GalaSoft.MvvmLight.Extras.dll</HintPath>
      <Private>True</Private>
    </Reference>
    <Reference Include="Microsoft.Practices.ServiceLocation, Version=1.3.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL">
      <HintPath>..\..\packages\CommonServiceLocator.1.3\lib\portable-net4+sl5+netcore45+wpa81+wp8\Microsoft.Practices.ServiceLocation.dll</HintPath>
      <Private>True</Private>
    </Reference>
  </ItemGroup>
'@
        [string]$testfilepath = (Join-Path $dest 'sample1.txt')
        Create-TestFileAt -path $testfilepath -content $contents

        $packageString = InternalGet-PackageStringsFromFile -files $testfilepath

        Update-PWPackagesPath -filesToUpdate $testfilepath -solutionRoot (((Get-Item $dest).FullName).TrimEnd('\').TrimEnd('/'))
        [System.IO.File]::ReadAllText($testfilepath).Contains('<HintPath>.\packages\') | Should be $true
        [System.IO.File]::ReadAllText($testfilepath).Contains('<HintPath>..\..\packages\') | Should be $false
    }
}
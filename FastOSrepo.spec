
%define CommitVersion %(echo $COMMIT_VERSION)

Name: FastOSrepo
Version: 1.0.0
Release: 1%{?dist}
Summary: FastOS repo for yum
License: LGPL
Group: System Environment/Base
URL:  http://github.com/happyfish100/FastOSrepo/
Source: http://github.com/happyfish100/FastOSrepo/%{name}-%{version}.tar.gz

BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n) 
Requires: %__cp %__mv %__chmod %__grep %__mkdir %__install %__id

%description
FastOS repo for yum
the rpm packages in FastOS.repo include: libfastcommon, libserverframe, FastCFS etc.
commit version: %{CommitVersion}

%prep
%setup -q

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/etc/yum.repos.d/
mkdir -p %{buildroot}/etc/pki/rpm-gpg/
cp yumrepo/FastOS.repo %{buildroot}/etc/yum.repos.d/
cp yumrepo/RPM-GPG-KEY-FastOS %{buildroot}/etc/pki/rpm-gpg/

%post

%preun

%postun

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
/etc/yum.repos.d/FastOS.repo
/etc/pki/rpm-gpg/RPM-GPG-KEY-FastOS

%changelog
* Sat Jan 2 2021 YuQing <384681@qq.com>
- first RPM release (1.0)

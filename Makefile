include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-hbasstunet
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=Applications
  TITLE:=hbasstuNet campus network login
  DEPENDS:=+luci-base +curl +jsonfilter
endef

define Package/$(PKG_NAME)/description
 LuCI frontend and background service for hbasstuNet campus network authentication.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/hbasstunet
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d $(1)/usr/sbin
	$(INSTALL_CONF) ./root/etc/config/hbasstunet $(1)/etc/config/hbasstunet
	$(INSTALL_BIN) ./root/etc/init.d/hbasstunet $(1)/etc/init.d/hbasstunet
	$(INSTALL_BIN) ./root/usr/sbin/hbasstunet $(1)/usr/sbin/hbasstunet
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./root/usr/lib/lua/luci/controller/hbasstunet.lua $(1)/usr/lib/lua/luci/controller/hbasstunet.lua
	$(INSTALL_DATA) ./root/usr/lib/lua/luci/model/cbi/hbasstunet.lua $(1)/usr/lib/lua/luci/model/cbi/hbasstunet.lua
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
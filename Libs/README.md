ElementHousing uses only these shared launcher libraries. It contains no housing implementation or artwork from Housing Decor Guide.

- LibStub and CallbackHandler-1.0: standard WoW library loaders/callbacks, bundled from the installed ElvUI_Libraries shared library set.
- LibDataBroker-1.1: the standard launcher interface, bundled from ElvUI_Libraries.
- LibDBIcon-1.0, minor 55: the standard minimap button implementation, bundled from the installed WorldQuestTracker library set.

Upstream: https://www.wowace.com/projects/libstub, https://www.wowace.com/projects/callbackhandler, https://github.com/tekkub/libdatabroker-1-1, https://www.wowace.com/projects/libdbicon-1-0.
Original library headers are retained. These libraries are shared through LibStub; existing compatible versions loaded by ElvUI or other addons are reused.

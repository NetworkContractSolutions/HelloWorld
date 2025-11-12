using Microsoft.Playwright;
using Microsoft.Playwright.NUnit;
using NUnit.Framework;

namespace HelloWorld.IntegrationTests
{
    [TestFixture]
    public class HomeTest : PageTest
    {
        private string _homePageUrl = "https://helloworld.localtest.me";

        [SetUp]
        public async Task HomeTestInitialize()
        {
            string homePageUrl = Environment.GetEnvironmentVariable("HomePageUrl");
            if (!string.IsNullOrEmpty(homePageUrl))
            {
                _homePageUrl = homePageUrl;
            }
        }

        [Test]
        public async Task NavigateToWebsiteRoot()
        {
            await Page.GotoAsync(_homePageUrl);
            var home = new HelloWorldHome(Page);
            Assert.That(await home.IsOnHomePage(_homePageUrl), Is.True, "Home page should be displayed.");
            Assert.That(await home.PageHasHomeTitle(), Is.True, "Home page should have correct title.");
        }

        [Test]
        public async Task NavigateToPrivacyPageFromNav()
        {
            await Page.GotoAsync(_homePageUrl);
            var home = new HelloWorldHome(Page);
            await home.ClickPrivacyNav();
            Assert.That(await home.IsOnPrivacyPage(), Is.True, "Privacy page should be displayed.");
        }

        [Test]
        public async Task NavigateToHomeFromPrivacyUsingBrand()
        {
            await Page.GotoAsync(_homePageUrl);
            var home = new HelloWorldHome(Page);
            await home.ClickPrivacyNav();
            await home.ClickBrand();
            Assert.That(await home.IsOnHomePage(_homePageUrl), Is.True, "Home page should be displayed.");
        }
    }

    public class HelloWorldHome
    {
        private readonly IPage _page;

        public HelloWorldHome(IPage page)
        {
            _page = page;
        }

        public async Task<bool> PageHasHomeTitle()
        {
            var title = await _page.TitleAsync();
            return title == "Home Page - HelloWorld";
        }

        public async Task<bool> PageHasPrivacyTitle()
        {
            var title = await _page.TitleAsync();
            return title == "Privacy Policy - HelloWorld";
        }

        public async Task<HelloWorldHome> ClickBrand()
        {
            await _page.Locator("#brandLink").ClickAsync();
            return this;
        }

        public async Task<HelloWorldHome> ClickHomeNav()
        {
            await _page.Locator("#homeNavLink").ClickAsync();
            return this;
        }

        public async Task<HelloWorldHome> ClickPrivacyNav()
        {
            await _page.Locator("#privacyNavLink").ClickAsync();
            return this;
        }

        public async Task<HelloWorldHome> ClickLearnAbout()
        {
            await _page.Locator("#learnAboutLink").ClickAsync();
            return this;
        }

        public async Task<HelloWorldHome> ClickPrivacyFooter()
        {
            await _page.Locator("#privacyFooterLink").ClickAsync();
            return this;
        }

        public async Task<bool> IsOnHomePage(string baseUrl)
        {
            try
            {
                var url = DriverUrl();
                return url.Equals(baseUrl, StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                return false;
            }
        }

        private string DriverUrl()
        {
            return _page.Url.TrimEnd('/');
        }

        public async Task<bool> IsOnPrivacyPage()
        {
            try
            {
                return DriverUrl().EndsWith("/Home/Privacy", StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                return false;
            }
        }
    }
}

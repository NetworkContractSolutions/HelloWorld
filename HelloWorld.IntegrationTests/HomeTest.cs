using OpenQA.Selenium;
using OpenQA.Selenium.Chrome;
using OpenQA.Selenium.Support.UI;
using NUnit.Framework;

namespace HelloWorld.IntegrationTests
{
    [TestFixture]
    public class HomeTest
    {
        private string _homePageUrl = "https://helloworld.localtest.me";

        [SetUp]
        public void HomeTestInitialize()
        {
            string homePageUrl = Environment.GetEnvironmentVariable("HomePageUrl");
            if (!string.IsNullOrEmpty(homePageUrl))
            {
                _homePageUrl = homePageUrl;
            }
        }

        [Test]
        public void NavigateToWebsiteRoot()
        {
            using (var driver = new ChromeDriver())
            {
                driver.Url = _homePageUrl;
                driver.Navigate();
                var home = new HelloWorldHome(driver);
                Assert.IsTrue(home.IsOnHomePage(_homePageUrl), "Home page should be displayed.");
                Assert.IsTrue(home.PageHasHomeTitle(), "Home page should be displayed.");
            }
        }

        [Test]
        public void NavigateToPrivacyPageFromNav()
        {
            using (var driver = new ChromeDriver())
            {
                driver.Url = _homePageUrl;
                driver.Navigate();
                var home = new HelloWorldHome(driver);
                var privacy = home.ClickPrivacyNav();
                Assert.IsTrue(privacy.IsOnPrivacyPage(), "Privacy page should be displayed.");
            }
        }
        [Test]
        public void NavigateToHomeFromPrivacyUsingBrand()
        {
            using (var driver = new ChromeDriver())
            {
                driver.Url = _homePageUrl;
                driver.Navigate();
                var home = new HelloWorldHome(driver);
                home.ClickPrivacyNav();
                var privacy = home.ClickBrand();
                Assert.IsTrue(home.IsOnHomePage(_homePageUrl), "Home page should be displayed.");
            }
        }
    }

    public class HelloWorldHome
    {
        private readonly ChromeDriver _driver;

        public HelloWorldHome(ChromeDriver driver)
        {
            _driver = driver;
        }

        public bool PageHasHomeTitle()
        {
            return _driver.Title == "Home Page - HelloWorld";
        }

        public bool PageHasPrivacyTitle()
        {
            return _driver.Title == "Privacy Policy - HelloWorld";
        }

        public HelloWorldHome ClickBrand()
        {
            WebDriverWait wait = new WebDriverWait(_driver, TimeSpan.FromSeconds(5));
            IWebElement firstResult = wait.Until(e => e.FindElement(By.Id("brandLink")));

            firstResult?.Click();

            return this;
        }

        public HelloWorldHome ClickHomeNav()
        {
            WebDriverWait wait = new WebDriverWait(_driver, TimeSpan.FromSeconds(5));
            IWebElement firstResult = wait.Until(e => e.FindElement(By.Id("homeNavLink")));

            firstResult?.Click();

            return this;
        }

        public HelloWorldHome ClickPrivacyNav()
        {
            WebDriverWait wait = new WebDriverWait(_driver, TimeSpan.FromSeconds(5));
            IWebElement firstResult = wait.Until(e => e.FindElement(By.Id("privacyNavLink")));

            firstResult?.Click();

            return this;
        }

        public HelloWorldHome ClickLearnAbout()
        {
            WebDriverWait wait = new WebDriverWait(_driver, TimeSpan.FromSeconds(5));
            IWebElement firstResult = wait.Until(e => e.FindElement(By.Id("learnAboutLink")));

            firstResult?.Click();

            return this;
        }

        public HelloWorldHome ClickPrivacyFooter()
        {
            WebDriverWait wait = new WebDriverWait(_driver, TimeSpan.FromSeconds(5));
            IWebElement firstResult = wait.Until(e => e.FindElement(By.Id("privacyFooterLink")));

            firstResult?.Click();

            return this;
        }

        public bool IsOnHomePage(string baseUrl)
        {
            try
            {
                return DriverUrl().Equals(baseUrl, StringComparison.OrdinalIgnoreCase);
            }
            catch { }

            return false;
        }

        private string DriverUrl()
        {
            return _driver.Url.TrimEnd('/');
        }

        public bool IsOnPrivacyPage()
        {
            try
            {
                return DriverUrl().EndsWith("/Home/Privacy", StringComparison.OrdinalIgnoreCase);
            }
            catch { }

            return false;
        }
    }
}

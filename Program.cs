using System;
using System.Collections.Generic;
using Npgsql;

namespace AutoServiceApp
{
    public class ActiveVehicle
    {
        public string LicensePlate { get; set; } = string.Empty;
        public string BrandName { get; set; } = string.Empty;
        public string ModelName { get; set; } = string.Empty;
    }

    public class UnpaidFine
    {
        public DateTime FineDate { get; set; }
        public decimal Amount { get; set; }
        public string LicensePlate { get; set; } = string.Empty;
    }

    public interface IVehicleRepository
    {
        List<ActiveVehicle> GetActiveVehicles();
        void UpdateMileage(int vehicleId, int newMileage);
    }

    public interface IFineRepository
    {
        List<UnpaidFine> GetUnpaidFines();
        void PayFine(int fineId);
    }

    public interface IUnitOfWork : IDisposable
    {
        IVehicleRepository Vehicles { get; }
        IFineRepository Fines { get; }
        void Commit();
        void Rollback();
    }

    public class VehicleRepository : IVehicleRepository
    {
        private readonly NpgsqlConnection _connection;
        private readonly NpgsqlTransaction _transaction;

        public VehicleRepository(NpgsqlConnection connection, NpgsqlTransaction transaction)
        {
            _connection = connection;
            _transaction = transaction;
        }

        public List<ActiveVehicle> GetActiveVehicles()
        {
            var vehicles = new List<ActiveVehicle>();
            using var cmd = new NpgsqlCommand("SELECT license_plate, brand_name, model_name FROM v_active_vehicles", _connection, _transaction);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                vehicles.Add(new ActiveVehicle
                {
                    LicensePlate = reader.GetString(0),
                    BrandName = reader.GetString(1),
                    ModelName = reader.GetString(2)
                });
            }
            return vehicles;
        }

        public void UpdateMileage(int vehicleId, int newMileage)
        {
            using var cmd = new NpgsqlCommand("CALL sp_update_mileage(@p1, @p2)", _connection, _transaction);
            cmd.Parameters.AddWithValue("p1", vehicleId);
            cmd.Parameters.AddWithValue("p2", newMileage);
            cmd.ExecuteNonQuery();
        }
    }

    public class FineRepository : IFineRepository
    {
        private readonly NpgsqlConnection _connection;
        private readonly NpgsqlTransaction _transaction;

        public FineRepository(NpgsqlConnection connection, NpgsqlTransaction transaction)
        {
            _connection = connection;
            _transaction = transaction;
        }

        public List<UnpaidFine> GetUnpaidFines()
        {
            var fines = new List<UnpaidFine>();
            using var cmd = new NpgsqlCommand("SELECT fine_date, amount, license_plate FROM v_unpaid_fines", _connection, _transaction);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                fines.Add(new UnpaidFine
                {
                    FineDate = reader.GetDateTime(0),
                    Amount = reader.GetDecimal(1),
                    LicensePlate = reader.GetString(2)
                });
            }
            return fines;
        }

        public void PayFine(int fineId)
        {
            using var cmd = new NpgsqlCommand("CALL sp_pay_fine(@p1)", _connection, _transaction);
            cmd.Parameters.AddWithValue("p1", fineId);
            cmd.ExecuteNonQuery();
        }
    }

    public class UnitOfWork : IUnitOfWork
    {
        private readonly NpgsqlConnection _connection;
        private readonly NpgsqlTransaction _transaction;

        public IVehicleRepository Vehicles { get; }
        public IFineRepository Fines { get; }

        public UnitOfWork(string connectionString)
        {
            _connection = new NpgsqlConnection(connectionString);
            _connection.Open();
            _transaction = _connection.BeginTransaction();

            Vehicles = new VehicleRepository(_connection, _transaction);
            Fines = new FineRepository(_connection, _transaction);
        }

        public void Commit() => _transaction.Commit();
        public void Rollback() => _transaction.Rollback();

        public void Dispose()
        {
            _transaction?.Dispose();
            _connection?.Close();
            _connection?.Dispose();
        }
    }

    class Program
    {
        static void Main()
        {
            Console.OutputEncoding = System.Text.Encoding.UTF8;
            string connectionString = "Host=localhost;Database=AutoService;Username=postgres;Password=+L4679013y";

            Console.WriteLine("Підключення до бази даних автопарку...\n");

            using (var uow = new UnitOfWork(connectionString))
            {
                try
                {
                    Console.WriteLine("--- Активні автомобілі (через View) ---");
                    var vehicles = uow.Vehicles.GetActiveVehicles();

                    if (vehicles.Count == 0)
                    {
                        Console.WriteLine("Автомобілів не знайдено.");
                    }
                    else
                    {
                        foreach (var v in vehicles)
                        {
                            Console.WriteLine($"- {v.BrandName} {v.ModelName} (Номер: {v.LicensePlate})");
                        }
                    }

                    Console.WriteLine("\n--- Неоплачені штрафи ---");
                    var fines = uow.Fines.GetUnpaidFines();
                    if (fines.Count == 0)
                    {
                        Console.WriteLine("Неоплачених штрафів немає.");
                    }
                    else
                    {
                        foreach (var f in fines)
                        {
                            Console.WriteLine($"- Авто: {f.LicensePlate}, Сума: {f.Amount} грн, Дата: {f.FineDate.ToShortDateString()}");
                        }
                    }

                    Console.WriteLine("\nТранзакція (Unit of Work) успішно завершена!");
                    uow.Commit();
                }
                catch (Exception ex)
                {
                    uow.Rollback();
                    Console.WriteLine($"\nПомилка БД! Зміни скасовано.\nДеталі: {ex.Message}");
                }
            }

            Console.ReadLine();
        }
    }
}
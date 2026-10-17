using System;
using System.Collections.Generic;
using Npgsql;

namespace AutoServiceApp
{
    public class ActiveVehicle
    {
        public int VehicleId { get; set; }
        public string LicensePlate { get; set; } = string.Empty;
        public string BrandName { get; set; } = string.Empty;
        public string ModelName { get; set; } = string.Empty;
        public int Mileage { get; set; }
    }

    public class UnpaidFine
    {
        public int FineId { get; set; }
        public int VehicleId { get; set; }
        public DateTime FineDate { get; set; }
        public decimal Amount { get; set; }
        public string LicensePlate { get; set; } = string.Empty;
    }

    public interface IVehicleRepository
    {
        List<ActiveVehicle> GetActiveVehicles();
        void UpdateMileage(int vehicleId, int newMileage);
        void SoftDeleteVehicle(int vehicleId);
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
            using var cmd = new NpgsqlCommand(
                "SELECT vehicle_id, license_plate, brand_name, model_name, mileage FROM v_active_vehicles ORDER BY vehicle_id",
                _connection, _transaction);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                vehicles.Add(new ActiveVehicle
                {
                    VehicleId = reader.GetInt32(0),
                    LicensePlate = reader.GetString(1),
                    BrandName = reader.GetString(2),
                    ModelName = reader.GetString(3),
                    Mileage = reader.GetInt32(4)
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

        public void SoftDeleteVehicle(int vehicleId)
        {
            using var cmd = new NpgsqlCommand("CALL sp_delete_vehicle(@p1)", _connection, _transaction);
            cmd.Parameters.AddWithValue("p1", vehicleId);
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
            using var cmd = new NpgsqlCommand(
                "SELECT fine_id, vehicle_id, fine_date, amount, license_plate FROM v_unpaid_fines ORDER BY fine_id",
                _connection, _transaction);
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                fines.Add(new UnpaidFine
                {
                    FineId = reader.GetInt32(0),
                    VehicleId = reader.GetInt32(1),
                    FineDate = reader.GetDateTime(2),
                    Amount = reader.GetDecimal(3),
                    LicensePlate = reader.GetString(4)
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
                    Console.WriteLine("--- Активні автомобілі (через View v_active_vehicles) ---");
                    var vehicles = uow.Vehicles.GetActiveVehicles();
                    foreach (var v in vehicles)
                    {
                        Console.WriteLine($"[ID: {v.VehicleId}] {v.BrandName} {v.ModelName} (Номер: {v.LicensePlate}, Пробіг: {v.Mileage} км)");
                    }

                    Console.WriteLine("\n--- Неоплачені штрафи (через View v_unpaid_fines) ---");
                    var fines = uow.Fines.GetUnpaidFines();
                    foreach (var f in fines)
                    {
                        Console.WriteLine($"[Штраф ID: {f.FineId}] Авто: {f.LicensePlate} (ID авто: {f.VehicleId}), Сума: {f.Amount} грн, Дата: {f.FineDate:dd.MM.yyyy}");
                    }

                    if (fines.Count > 0)
                    {
                        var fineToPay = fines[0];
                        Console.WriteLine($"\n-> Оплата штрафу ID {fineToPay.FineId} для авто {fineToPay.LicensePlate} (CALL sp_pay_fine)...");
                        uow.Fines.PayFine(fineToPay.FineId);

                        var relatedVehicle = vehicles.Find(v => v.VehicleId == fineToPay.VehicleId);
                        if (relatedVehicle != null)
                        {
                            int updatedMileage = relatedVehicle.Mileage + 150;
                            Console.WriteLine($"-> Оновлення пробігу авто ID {relatedVehicle.VehicleId} до {updatedMileage} км (CALL sp_update_mileage)...");
                            uow.Vehicles.UpdateMileage(relatedVehicle.VehicleId, updatedMileage);
                        }
                    }

                    uow.Commit();
                    Console.WriteLine("\nТранзакція (Unit of Work) успішно зафіксована (Commit)!");
                }
                catch (Exception ex)
                {
                    uow.Rollback();
                    Console.WriteLine($"\nПомилка БД! Зміни скасовано (Rollback).\nДеталі: {ex.Message}");
                }
            }
        }
    }
}